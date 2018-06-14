module Devcard.Context exposing (CardContext, dynamic, initialize, none, static, view)

{-|


# Devcard.Context

@docs CardContext, initialize, view, none, static, dynamic

-}

import Html exposing (Html)
import Random


{-| -}
type CardContext c
    = Context
        { init : Random.Seed -> c
        , view : c -> Html c
        }


{-| -}
initialize : CardContext c -> Random.Seed -> c
initialize (Context { init }) seed =
    init seed


{-| -}
view : CardContext c -> c -> Html c
view (Context { view }) c =
    view c


{-| -}
none : CardContext ()
none =
    Context
        { init = always ()
        , view = noView
        }


{-| -}
static : c -> CardContext c
static c =
    Context
        { init = always c
        , view = noView
        }


{-| -}
dynamic : (Random.Seed -> c) -> (c -> Html c) -> CardContext c
dynamic i v =
    Context
        { init = i, view = v }


{-| -}
noView : b -> Html msg
noView =
    always (Html.text "")
