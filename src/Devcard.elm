module Devcard exposing (BasicConfig, Config, Devcard, basicDevcard, devcard, staticDevcard)

{-|


# Devcard

@docs BasicConfig, Config, Devcard, basicDevcard, devcard, staticDevcard

-}

import Browser
import Devcard.Context as Context exposing (CardContext)
import Html exposing (Html)
import Html.Attributes
import Html.Events
import Random
import Task
import Time exposing (Posix)


{-| -}
type alias Model sub subMsg context =
    { flags : Flags
    , context : CardContext context
    , state : State sub subMsg context
    , footer : Bool
    , config : Config sub subMsg context
    }


{-| -}
type State sub subMsg context
    = Loading
    | Loaded
        { sub : sub
        , contextValue : context
        , msgs : List subMsg
        }


{-| -}
type Msg subMsg context
    = SubMsg subMsg
    | ContextMsg context
    | ToggleFooter
    | Tick Posix


{-| -}
type alias Devcard model msg context =
    Program Flags (Model model msg context) (Msg msg context)


{-| -}
type alias BasicConfig model msg context =
    { model : model
    , update : msg -> model -> model
    , view : context -> model -> Html msg
    , modelToString : model -> String
    , msgToString : msg -> String
    }


{-| -}
type alias Config model msg context =
    { model : context -> ( model, Cmd msg )
    , update : msg -> model -> ( model, Cmd msg )
    , view : context -> model -> Html msg
    , subscriptions : model -> Sub msg
    , modelToString : model -> String
    , msgToString : msg -> String
    }


{-| -}
staticDevcard : CardContext context -> (context -> Html Never) -> Devcard () Never context
staticDevcard context f =
    devcard
        context
        { model = always ( (), Cmd.none )
        , update = \_ m -> ( m, Cmd.none )
        , view = \c _ -> f c
        , subscriptions = always Sub.none
        , modelToString = always ""
        , msgToString = always ""
        }


{-| -}
basicDevcard : CardContext context -> BasicConfig model msg context -> Devcard model msg context
basicDevcard context config =
    devcard context
        { model = always ( config.model, Cmd.none )
        , update = \msg model -> ( config.update msg model, Cmd.none )
        , view = config.view
        , subscriptions = always Sub.none
        , modelToString = config.modelToString
        , msgToString = config.msgToString
        }


{-| -}
devcard : CardContext context -> Config model msg context -> Devcard model msg context
devcard context config =
    Browser.element
        { init = init context config
        , update = update
        , view = view
        , subscriptions = subscriptions
        }


{-| -}
type alias Flags =
    { name : String
    }


{-| -}
init : CardContext context -> Config sub subMsg context -> Flags -> ( Model sub subMsg context, Cmd (Msg subMsg context) )
init context config flags =
    ( { flags = flags
      , config = config
      , context = context
      , footer = False
      , state = Loading
      }
    , Time.now |> Task.perform Tick
    )


{-| -}
subscriptions : Model sub subMsg context -> Sub (Msg subMsg context)
subscriptions model =
    case model.state of
        Loading ->
            Sub.none

        Loaded inner ->
            model.config.subscriptions inner.sub
                |> Sub.map SubMsg


{-| -}
update : Msg subMsg context -> Model sub subMsg context -> ( Model sub subMsg context, Cmd (Msg subMsg context) )
update msg model =
    case msg of
        SubMsg m ->
            case model.state of
                Loaded inner ->
                    let
                        ( newSub, newSubMsgs ) =
                            model.config.update m inner.sub

                        newInner =
                            { inner | sub = newSub, msgs = m :: inner.msgs }
                    in
                    ( { model | state = Loaded newInner }
                    , Cmd.map SubMsg newSubMsgs
                    )

                _ ->
                    ( model, Cmd.none )

        ContextMsg newContext ->
            case model.state of
                Loaded inner ->
                    ( { model | state = Loaded { inner | contextValue = newContext } }
                    , Cmd.none
                    )

                _ ->
                    ( model, Cmd.none )

        ToggleFooter ->
            ( { model | footer = not model.footer }
            , Cmd.none
            )

        Tick time ->
            let
                seed =
                    Random.initialSeed (Time.posixToMillis time)

                contextValue =
                    Context.initialize model.context seed

                ( subModel, subMsgs ) =
                    model.config.model contextValue
            in
            ( { model
                | state =
                    Loaded
                        { sub = subModel
                        , contextValue = contextValue
                        , msgs = []
                        }
              }
            , Cmd.map SubMsg subMsgs
            )


{-| -}
view : Model model subMsg context -> Html (Msg subMsg context)
view model =
    case model.state of
        Loading ->
            Html.div []
                [ Html.div [ Html.Attributes.class "devcard-header" ]
                    [ Html.h1 []
                        [ Html.a [ Html.Attributes.href ("/" ++ model.flags.name) ] [ Html.text model.flags.name ] ]
                    ]
                , Html.div [ Html.Attributes.class "devcard-body" ]
                    [ Html.text "Loading..."
                    ]
                ]

        Loaded inner ->
            Html.div []
                [ Html.div [ Html.Attributes.class "devcard-header" ]
                    [ Html.div
                        [ Html.Attributes.style "float" "right" ]
                        [ Context.view model.context inner.contextValue |> Html.map ContextMsg ]
                    , Html.h1 []
                        [ Html.a [ Html.Attributes.href ("/" ++ model.flags.name) ] [ Html.text model.flags.name ] ]
                    ]
                , Html.div [ Html.Attributes.class "devcard-body" ]
                    [ model.config.view inner.contextValue inner.sub |> Html.map SubMsg
                    ]
                , Html.div [ Html.Attributes.class "devcard-footer" ] <|
                    if model.footer then
                        [ toggleFooterButton
                        , Html.h4 [] [ Html.text "State" ]
                        , Html.pre []
                            [ Html.text (model.config.modelToString inner.sub) ]
                        , Html.hr []
                            []
                        , Html.h4 [] [ Html.text "Events" ]
                        , Html.pre []
                            [ inner.msgs
                                |> List.map model.config.msgToString
                                |> String.join "\n"
                                |> Html.text
                            ]
                        ]

                    else
                        [ toggleFooterButton ]
                ]


{-| -}
toggleFooterButton : Html (Msg subMsg context)
toggleFooterButton =
    Html.button
        [ Html.Events.onClick ToggleFooter
        , Html.Attributes.class "toggle-button"
        ]
        [ Html.text "Toggle footer"
        ]
