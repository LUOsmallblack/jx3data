module Wrapper = {
  type action = Open | Close;
  type state = {
    tooltipRef: ref(option(ReasonReact.reactRef)),
    selfRef: ref(option(Dom.element)),
    status: action,
  };

  let component = ReasonReact.reducerComponent("TooltipWrapper");

  let show = (factory, selfRef, tooltipRef) => {
    Js.log("show");
  };
  let hide = (selfRef, tooltipRef) => {
    Js.log("hide");
  };
  let setSelfRef = (theRef, {ReasonReact.state}) => {
    state.selfRef := Js.Nullable.toOption(theRef);
    /* wondering about Js.Nullable.toOption? See the note below */
  };

  let make = (~tooltipRef, ~factory, children) => {
    ...component,
    initialState: () => {tooltipRef, selfRef: ref(None), status: Close},
    reducer: (action, state) => {
      switch (action, state.status==action) {
      | (_, true) => ReasonReact.NoUpdate
      | (Open, _) =>
        ReasonReact.UpdateWithSideEffects(
          {...state, status: Open},
          self => show(factory, self.state.selfRef^, self.state.tooltipRef))
      | (Close, _) =>
        ReasonReact.UpdateWithSideEffects(
          {...state, status: Close},
          self => hide(self.state.selfRef^, self.state.tooltipRef))
      }
    },
    render: self => {
      let enter = (_, self) => self.ReasonReact.send(Open);
      let leave = (_, self) => self.ReasonReact.send(Close);
      <div ref={self.handle(setSelfRef)} onMouseEnter={self.handle(enter)} onMouseLeave={self.handle(leave)}>
        ...children
      </div>
    }
  }
};

let component = ReasonReact.statelessComponent("Tooltip");
let make = (_children) => {
  ...component,
  render: _ =>
    <div>
      {ReasonReact.string("no tip")}
    </div>
}
