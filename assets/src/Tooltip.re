type popper;
[@bs.new] external createPopper : (Dom.element, Dom.element) => popper = "Popper";
[@bs.send] external destroyPopper : popper => unit = "destroy";

module type Component = {
  /* type component; */
  type props';
  /* TODO: support other componentSpec here */
  let make': (~props: props', _) => ReasonReact.component(ReasonReact.stateless, ReasonReact.noRetainedProps, ReasonReact.actionless);
};

module Type = (C: Component) => {
  type action = Reset | SetProps(C.props') | Show(Dom.element, bool);
  type state = { source: option(Dom.element), show: bool, props: option(C.props'), };
};

module Make = (C: Component) => {
  include Type(C);
  let component = ReasonReact.reducerComponent("Tooltip");
  module C' = {
    let make = C.make';
  };
  let make = (children) => {
    ...component,
    initialState: () => {show: false, props: None, source: None},
    reducer: (action, state) => {
      switch (action) {
      | Reset => ReasonReact.Update({...state, props: None})
      | SetProps(props) => ReasonReact.Update({...state, props: Some(props)})
      | Show(source, true) => ReasonReact.Update({...state, source: Some(source), show: true})
      | Show(source, false) when Some(source) == state.source => ReasonReact.Update({...state, show: false})
      | Show(_, false) => ReasonReact.NoUpdate
      }
    },
    render: ({state}) => {
      let {show, props} = state;
      let content = switch (props) {
      | Some(props) => <C' props>...children</C'>
      | None => {ReasonReact.string("loading...")}
      };
      <div hidden={!show} className="bg-light">
        {content}
      </div>
    }
  }
};

module Wrapper = (C: Component) => {
  module Tooltip = Type(C);
  type action = Open | Close | Popper(option(popper));
  type state = {
    tooltipRef: ref(option(ReasonReact.reactRef)),
    selfRef: ref(option(Dom.element)),
    status: action,
    popper: option(popper),
  };

  let component = ReasonReact.reducerComponent("TooltipWrapper");

  let setContent = (tooltip, props) => {
    switch (props) {
    | Some(props) => tooltip.ReasonReact.send(Tooltip.SetProps(props));
    | None => tooltip.ReasonReact.send(Tooltip.Reset);
    }
  };
  let show = (factory, send, selfRef, tooltipRef) => {
    Js.log("show");
    switch (tooltipRef^, selfRef^) {
    | (_, None)
    | (None, _) => ()
    | (Some(tooltipRef), Some(refElem)) =>
      let tooltip = Obj.magic(Obj.magic(tooltipRef)##self());
      factory(setContent(tooltip));
      tooltip.ReasonReact.send(Tooltip.Show(refElem, true));
      let popper = createPopper(refElem, ReactDOMRe.findDOMNode(tooltipRef));
      send(Popper(Some(popper)));
    };
  };
  let hide = (popper, send, selfRef, tooltipRef) => {
    Js.log("hide");
    switch (popper) {
    | None => ()
    | Some(popper) => /*destroyPopper(popper);*/ send(Popper(None))
    }
    switch (tooltipRef^, selfRef^) {
    | (_, None)
    | (None, _) => ()
    | (Some(tooltipRef), Some(refElem)) =>
      let tooltip = Obj.magic(Obj.magic(tooltipRef)##self());
      tooltip.ReasonReact.send(Tooltip.Show(refElem, false));
    };
  };
  let setSelfRef = (theRef, {ReasonReact.state}) => {
    state.selfRef := Js.Nullable.toOption(theRef);
    /* wondering about Js.Nullable.toOption? See the note below */
  };

  let make = (~tooltipRef, ~factory, children) => {
    ...component,
    initialState: () => {tooltipRef, selfRef: ref(None), status: Close, popper: None},
    reducer: (action, state) => {
      switch (action, state.status==action) {
      | (Popper(popper), _) => ReasonReact.Update({...state, popper: popper})
      | (_, true) => ReasonReact.NoUpdate
      | (Open, _) =>
        ReasonReact.UpdateWithSideEffects(
          {...state, status: Open},
          self => show(factory, self.send, self.state.selfRef, self.state.tooltipRef))
      | (Close, _) =>
        ReasonReact.UpdateWithSideEffects(
          {...state, status: Close},
          self => hide(self.state.popper, self.send, self.state.selfRef, self.state.tooltipRef))
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
