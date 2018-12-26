module type Component = {
  /* type component; */
  type props';
  /* TODO: support other componentSpec here */
  let make': (~props: props', _) => ReasonReact.component(ReasonReact.stateless, ReasonReact.noRetainedProps, ReasonReact.actionless);
};

/* module Test = (C: Component) => {
  let result = props => <C props/>
}; */

module Make = (C: Component) => {
  type action = Reset | SetProps(C.props') | Show(bool);
  type state = { show: bool, props: option(C.props'), };
  let component = ReasonReact.reducerComponent("Tooltip");
  module C' = {
    let make = C.make';
  };
  let make = (children) => {
    ...component,
    initialState: () => {show: false, props: None},
    reducer: (action, state) => {
      switch (action) {
      | Reset => ReasonReact.Update({...state, props: None})
      | SetProps(props) => ReasonReact.Update({...state, props: Some(props)})
      | Show(show) => ReasonReact.Update({...state, show})
      }
    },
    render: ({state}) => {
      let {show, props} = state;
      let content = switch (props) {
      | Some(props) => <C' props>...children</C'>
      | None => {ReasonReact.string("loading...")}
      };
      <div>
        {ReasonReact.string({j|show($show): |j})}
        {content}
      </div>
    }
  }
};

module Wrapper = (C: Component) => {
  module Tooltip = Make(C);
  type action = Open | Close;
  type state = {
    tooltipRef: ref(option(ReasonReact.reactRef)),
    selfRef: ref(option(Dom.element)),
    status: action,
  };

  let component = ReasonReact.reducerComponent("TooltipWrapper");

  let setContent = (tooltip, props) => {
    switch (props) {
    | Some(props) => tooltip.ReasonReact.send(Tooltip.SetProps(props));
    | None => tooltip.ReasonReact.send(Tooltip.Reset);
    }
  };
  let show = (factory, selfRef, tooltipRef) => {
    Js.log("show");
    switch (tooltipRef^) {
    | None => ()
    | Some(tooltipRef) =>
      let tooltip = Obj.magic(Obj.magic(tooltipRef)##self());
      factory(setContent(tooltip));
      tooltip.ReasonReact.send(Tooltip.Show(true));
    };
  };
  let hide = (selfRef, tooltipRef) => {
    Js.log("hide");
    switch (tooltipRef^) {
    | None => ()
    | Some(tooltipRef) =>
      let tooltip = Obj.magic(Obj.magic(tooltipRef)##self());
      tooltip.ReasonReact.send(Tooltip.Show(false));
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
