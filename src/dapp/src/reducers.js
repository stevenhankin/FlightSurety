import {createReducer, createAction} from "redux-starter-kit";
import {addFlight} from "./actions";

// const addFlight = createAction('addFlight');

export const flightReducer = createReducer([], {
    [addFlight]: (state, action) => { console.log('here!!!') ;return [...state, action.payload]}
});

