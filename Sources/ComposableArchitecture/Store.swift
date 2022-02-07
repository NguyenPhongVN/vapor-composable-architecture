import OpenCombine
import Foundation

public final class Store<State, Action> {
  private var bufferedActions: [Action] = []
  var effectCancellables: [UUID: AnyCancellable] = [:]
  private var isSending = false
  var parentCancellable: AnyCancellable?
  private let reducer: (inout State, Action) -> Effect<Action, Never>
  var state: CurrentValueSubject<State, Never>

  public convenience init<Environment>(
    initialState: State,
    reducer: Reducer<State, Action, Environment>,
    environment: Environment
  ) {
    self.init(
      initialState: initialState,
      reducer: reducer,
      environment: environment,
      mainThreadChecksEnabled: true
    )
    self.threadCheck(status: .`init`)
  }

  public static func unchecked<Environment>(
    initialState: State,
    reducer: Reducer<State, Action, Environment>,
    environment: Environment
  ) -> Self {
    Self(
      initialState: initialState,
      reducer: reducer,
      environment: environment,
      mainThreadChecksEnabled: false
    )
  }

  public func scope<LocalState, LocalAction>(
    state toLocalState: @escaping (State) -> LocalState,
    action fromLocalAction: @escaping (LocalAction) -> Action
  ) -> Store<LocalState, LocalAction> {
    self.threadCheck(status: .scope)
    var isSending = false
    let localStore = Store<LocalState, LocalAction>(
      initialState: toLocalState(self.state.value),
      reducer: .init { localState, localAction, _ in
        isSending = true
        defer { isSending = false }
        self.send(fromLocalAction(localAction))
        localState = toLocalState(self.state.value)
        return .none
      },
      environment: ()
    )
    localStore.parentCancellable = self.state
      .dropFirst()
      .sink { [weak localStore] newValue in
        guard !isSending else { return }
        localStore?.state.value = toLocalState(newValue)
      }
    return localStore
  }

  public func scope<LocalState>(
    state toLocalState: @escaping (State) -> LocalState
  ) -> Store<LocalState, Action> {
    self.scope(state: toLocalState, action: { $0 })
  }

  func send(_ action: Action, originatingFrom originatingAction: Action? = nil) {
    self.threadCheck(status: .send(action, originatingAction: originatingAction))

    self.bufferedActions.append(action)
    guard !self.isSending else { return }

    self.isSending = true
    var currentState = self.state.value
    defer {
      self.isSending = false
      self.state.value = currentState
    }

    while !self.bufferedActions.isEmpty {
      let action = self.bufferedActions.removeFirst()
      let effect = self.reducer(&currentState, action)

      var didComplete = false
      let uuid = UUID()
      let effectCancellable = effect.sink(
        receiveCompletion: { [weak self] _ in
          self?.threadCheck(status: .effectCompletion(action))
          didComplete = true
          self?.effectCancellables[uuid] = nil
        },
        receiveValue: { [weak self] effectAction in
          self?.send(effectAction, originatingFrom: action)
        }
      )

      if !didComplete {
        self.effectCancellables[uuid] = effectCancellable
      }
    }
  }

  public var stateless: Store<Void, Action> {
    self.scope(state: { _ in () })
  }

  public var actionless: Store<State, Never> {
    func absurd<A>(_ never: Never) -> A {}
    return self.scope(state: { $0 }, action: absurd)
  }

  private enum ThreadCheckStatus {
    case effectCompletion(Action)
    case `init`
    case scope
    case send(Action, originatingAction: Action?)
  }

  @inline(__always)
  private func threadCheck(status: ThreadCheckStatus) {

  }

  private init<Environment>(
    initialState: State,
    reducer: Reducer<State, Action, Environment>,
    environment: Environment,
    mainThreadChecksEnabled: Bool
  ) {
    self.state = CurrentValueSubject(initialState)
    self.reducer = { state, action in reducer.run(&state, action, environment) }
  }
}

extension Store {
  public func ifLet<Wrapped>(
    then unwrap: @escaping (Store<Wrapped, Action>) -> Void,
    else: @escaping () -> Void = {}
  ) -> Cancellable where State == Wrapped? {
    return self.state
      .removeDuplicates(by: { ($0 != nil) == ($1 != nil) })
      .sink { state in
        if var state = state {
          unwrap(
            self.scope {
              state = $0 ?? state
              return state
            }
          )
        } else {
          `else`()
        }
      }
  }
}
