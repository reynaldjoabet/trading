module View exposing (..)

import Debug exposing (toString)
import Dict exposing (Dict)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Json.Decode as D
import Model exposing (..)
import Utils exposing (emptyMaybe)


subscriptionSuccess : Model -> Html Msg
subscriptionSuccess model =
    div [ hidden (emptyMaybe model.sub), id "subscription-success", class "alert alert-success fade show" ]
        [ button
            [ class "close"
            , attribute "aria-label" "Close"
            , onClick CloseAlerts
            ]
            [ text "x" ]
        , text ("Subscribed to " ++ Maybe.withDefault "X" model.sub)
        ]


unsubscriptionSuccess : Model -> Html Msg
unsubscriptionSuccess model =
    div [ hidden (emptyMaybe model.unsub), id "unsubscription-success", class "alert alert-warning fade show" ]
        [ button
            [ class "close"
            , attribute "aria-label" "Close"
            , onClick CloseAlerts
            ]
            [ text "x" ]
        , text ("Unsubscribed from " ++ Maybe.withDefault "X" model.unsub)
        ]


view : Model -> Html Msg
view model =
    div [ class "container" ]
        [ subscriptionSuccess model
        , unsubscriptionSuccess model
        , h1 [] [ text "Trading WS" ]
        , div [ class "input-group mb-3" ]
            [ input
                [ type_ "text"
                , class "form-control"
                , autofocus True
                , placeholder "Symbol (e.g. EURUSD)"
                , onInput SymbolChanged
                , on "keydown" (ifIsEnter Subscribe)
                , value model.symbol
                ]
                []
            , div [ class "input-group-append" ]
                [ button [ class "btn btn-outline-primary btn-rounded", onClick Subscribe ]
                    [ text "Subscribe" ]
                ]
            ]
        , div [ id "sid-card", class "card" ]
            [ div [ class "sid-body" ]
                [ renderSocketId model.socketId ]
            ]
        , p [] []
        , table [ class "table table-inverse", hidden (Dict.isEmpty model.alerts) ]
            [ thead []
                [ tr []
                    [ th [] [ text "Symbol" ]
                    , th [] [ text "Price" ]
                    , th [] [ text "Status" ]
                    , th [] []
                    ]
                ]
            , tbody [] (List.map renderAlertRow (Dict.toList model.alerts))
            ]
        ]


renderSocketId : Maybe SocketId -> Html msg
renderSocketId maybeSid =
    case maybeSid of
        Just sid ->
            span [ id "socket-id", class "badge badge-pill badge-primary" ] [ text ("Socket ID: " ++ sid) ]

        Nothing ->
            span [ id "socket-id", class "badge badge-pill badge-danger" ] [ text "<Disconnected>" ]


renderAlertRow : ( Symbol, Alert ) -> Html Msg
renderAlertRow ( symbol, alert ) =
    tr []
        [ th [] [ text symbol ]
        , th [] [ alert.price |> toString |> text ]
        , th [] [ alert.alertType |> toString |> text ]
        , th [] [ button [ class "btn btn-danger", onClick (Unsubscribe symbol), title "Unsubscribe" ] [ text "X" ] ]
        ]


ifIsEnter : msg -> D.Decoder msg
ifIsEnter msg =
    D.field "key" D.string
        |> D.andThen
            (\key ->
                if key == "Enter" then
                    D.succeed msg

                else
                    D.fail "some other key"
            )