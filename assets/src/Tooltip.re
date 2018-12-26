type action = SetContent(array(ReasonReact.reactElement)) | Show(bool);
type state = { show: bool, children: array(ReasonReact.reactElement), };

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
    let children = [|factory()|];
    switch (tooltipRef^) {
    | None => ()
    | Some(tooltipRef) =>
      let tooltip = Obj.magic(Obj.magic(tooltipRef)##self());
      tooltip.ReasonReact.send(SetContent(children));
      tooltip.ReasonReact.send(Show(true));
    };
  };
  let hide = (selfRef, tooltipRef) => {
    Js.log("hide");
    switch (tooltipRef^) {
    | None => ()
    | Some(tooltipRef) =>
      let tooltip = Obj.magic(Obj.magic(tooltipRef)##self());
      tooltip.ReasonReact.send(Show(false));
    };
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
      <div ref={self.handle(setSelfRef)} className="d-inline" onMouseEnter={self.handle(enter)} onMouseLeave={self.handle(leave)}>
        ...children
      </div>
    }
  }
};

let component = ReasonReact.reducerComponent("Tooltip");
let make = (_children) => {
  ...component,
  initialState: () => {show: false, children: [|ReasonReact.string("no tip")|]},
  reducer: (action, state) => {
    switch (action) {
    | SetContent(children) => ReasonReact.Update({...state, children})
    | Show(show) => ReasonReact.Update({...state, show})
    }
  },
  render: ({state}) => {
    let show = state.show;
    <div>
      <span>{ReasonReact.string({j|show($show): |j})}</span>
      <span>...{state.children}</span>
    </div>
  }
}
