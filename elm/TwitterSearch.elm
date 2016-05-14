port module TwitterSearch exposing (..)

import Html exposing (..)
import Html.App
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Http
import Json.Decode as Json
import Json.Decode as Json exposing ((:=))
import Regex exposing (..)
import String exposing (..)
import Task exposing (Task)


port coords : ((Float, Float) -> msg) -> Sub msg

main : Program Never
main =
  Html.App.program
    { init = init (37.7767396, -122.4163715) ""
    , update = update
    , view = view
    , subscriptions = subscriptions
    }

-- MODEL

type alias Model =
  { currentCoords : (Float, Float)
  , currentQuery : String
  , token: String
  , tweets : List (String, String, (String, String), String)
  }


init : (Float, Float) -> String -> (Model, Cmd Action)
init initialCoords initialQuery =
  ( Model initialCoords initialQuery "none" []
  , obtainBearerToken
  )


-- UPDATE

type Action
  = ObtainTokenCommand
  | ObtainedToken (Maybe (String, String))
  | QueryChanged String
  | CoordsChanged (Float, Float)
  | SearchResults (Maybe (List (String, String, (String, String), String)))


update : Action -> Model -> (Model, Cmd Action)
update action model =
  case action of
    ObtainTokenCommand ->
      (model, obtainBearerToken)

    ObtainedToken maybeToken ->
      case maybeToken of
        Just (_, tokenValue) ->
          ( Model model.currentCoords model.currentQuery tokenValue model.tweets
          , sendTwitterQuery tokenValue model.currentCoords model.currentQuery
          )
        Nothing ->
          ( Model model.currentCoords model.currentQuery "fail" model.tweets
          , Cmd.none
          )

    CoordsChanged coords ->
      ( Model (Debug.log "new coords" coords) model.currentQuery model.token model.tweets
      , sendTwitterQuery model.token coords model.currentQuery
      )

    QueryChanged query ->
      ( Model model.currentCoords query model.token model.tweets
      , sendTwitterQuery model.token model.currentCoords query
      )

    SearchResults maybeTweets ->
      ( Model model.currentCoords model.currentQuery model.token (Maybe.withDefault model.tweets maybeTweets)
      , Cmd.none
      )

-- SUBSCRIPTIONS

subscriptions : Model -> Sub Action
subscriptions model =
  coords (CoordsChanged)

-- VIEW

(=>) : a -> b -> (a, b)
(=>) = (,)


view : Model -> Html Action
view model =
  div
    [ id "searchColumnDiv" ]
    [ queryInput model.currentQuery
    , div [ id "tweetListDiv" ] (List.map renderTweet model.tweets)
    , div [ class "signatureDiv"]
      [ Html.text "Made by "
      , Html.a [href "http://sergey.serebryakov.info"] [Html.text "megaserg"]
      , Html.text ", 2015."
      , Html.br [] []
      , Html.text "Built with Elm, Go, Google Maps API, Twitter Search API."
      ]
    ]


queryInput : String -> Html Action
queryInput string =
  input
    [ placeholder "Filter by word..."
    , value string
    , onInput QueryChanged
    , class "searchQueryInput"
    ]
    []


renderTweet : (String, String, (String, String), String) -> Html Action
renderTweet (tweetId, tweetText, (displayName, screenName), createdAt) =
  let
    tweetLink = "https://twitter.com/" ++ screenName ++ "/status/" ++ tweetId
    userLink = "https://twitter.com/" ++ screenName
    formattedDate = (String.dropRight 11 createdAt) ++ " UTC"

    makeLink : String -> Html Action
    makeLink url =
      a [href url] [Html.text url]

    makeText : String -> Html Action
    makeText txt =
      Html.text txt

    linkify : String -> List (Html Action)
    linkify text =
      let
        helper : String -> List (Html Action) -> List (Html Action)
        helper text acc =
          if text == "" then acc
          else
            let
              match = find (AtMost 1) (regex "https://t.co\\S+") text
            in
              case match of
                [] -> (makeText text) :: acc
                m :: ms ->
                  let
                    rest = if m.index > 0 then makeText (left m.index text) :: acc else acc
                  in
                    helper
                      (dropLeft (m.index + length m.match) text)
                      ((makeLink m.match) :: rest)

      in
        List.reverse (helper text [])
  in
    div
      [ class "tweetDiv" ]
      [ span [ class "userDisplayName" ]
        [ a
          [ href userLink ]
          [ Html.text displayName ]
        ]
      , span [ class "invisible" ] [ Html.text "." ]
      , span [ class "userScreenName" ]
        [ a
          [ href userLink ]
          [ Html.text ("@" ++ screenName) ]
        ]
      , span [ class "tweetMetadata" ]
          [ a [ href tweetLink ] [ Html.text formattedDate ] ]
      , br [] []
      , span [ class "tweetText" ] (linkify tweetText)
      ]

serverUrl : String
serverUrl = ""

sendTwitterQuery : String -> (Float, Float) -> String -> Cmd Action
sendTwitterQuery tokenValue coords query =
  let
    lat (latitude, _) = toString latitude
    lng (_, longitude) = toString longitude
    url =
      Http.url (serverUrl ++ "/search")
        [ ("authToken", tokenValue)
        , ("coords", (lat coords) ++ "," ++ (lng coords) ++ ",10km")
        , ("query", query)
        ]
  in
    sendGetRequest url []
      |> Http.fromJson searchResultsDecoder
      |> Task.toMaybe
      |> Task.perform SearchResults SearchResults


searchResultsDecoder : Json.Decoder (List (String, String, (String, String), String))
searchResultsDecoder =
  let
    statusDecoder : Json.Decoder (String, String, (String, String), String)
    statusDecoder =
      Json.object4 (,,,)
        ("id_str" := Json.string)
        ("text" := Json.string)
        ("user" := Json.object2 (,)
          ("name" := Json.string)
          ("screen_name" := Json.string)
        )
        ("created_at" := Json.string)
  in
    Json.object1 identity
      ("statuses" := Json.list statusDecoder)


tokenDecoder : Json.Decoder (String, String)
tokenDecoder =
  Json.object2 (,)
    ("token_type" := Json.string)
    ("access_token" := Json.string)


obtainBearerToken : Cmd Action
obtainBearerToken =
  let
    url = serverUrl ++ "/auth"
  in
    sendGetRequest url []
      |> Http.fromJson tokenDecoder
      |> Task.toMaybe
      |> Task.perform ObtainedToken ObtainedToken

sendGetRequest : String -> List (String, String) -> Task Http.RawError Http.Response
sendGetRequest url headers =
  Http.send Http.defaultSettings
    { verb = "GET"
    , url = url
    , headers = headers
    , body = Http.empty
    }


sendPostRequest : String -> List (String, String) -> Http.Body -> Task Http.RawError Http.Response
sendPostRequest url headers body =
  Http.send Http.defaultSettings
    { verb = "POST"
    , url = url
    , headers = headers
    , body = body
    }
