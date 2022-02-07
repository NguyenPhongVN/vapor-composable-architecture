import OpenCombine
import TokamakDOM

@dynamicMemberLookup
public final class ViewStore<State, Action>: TokamakDOM.ObservableObject {
  public private(set) lazy var objectWillChange = ObservableObjectPublisher()
  
  public let action = PassthroughSubject<Action, Never>()
  
  private let _send: (Action) -> Void
  fileprivate let _state: CurrentValueSubject<State, Never>
  private var viewCancellable: AnyCancellable?
  var cancellables: Set<AnyCancellable> = []

  public init(
    _ store: Store<State, Action>,
    removeDuplicates isDuplicate: @escaping (State, State) -> Bool
  ) {
    self._send = { store.send($0) }
    self._state = CurrentValueSubject(store.state.value)
    
    self.viewCancellable = store.state
      .removeDuplicates(by: isDuplicate)
      .sink { [weak self] in
        guard let self = self else { return }
        self.objectWillChange.send()
        self._state.value = $0
      }
    
    self.action.sink(receiveValue: self.send(_:))
      .store(in: &cancellables)
  }

  public var publisher: StorePublisher<State> {
    StorePublisher(viewStore: self)
  }
  
    /// The current state.
  public var state: State {
    self._state.value
  }
  
    /// Returns the resulting value of a given key path.
  public subscript<LocalState>(dynamicMember keyPath: KeyPath<State, LocalState>) -> LocalState {
    self._state.value[keyPath: keyPath]
  }

  public func send(_ action: Action) {
    self._send(action)
  }

  public func binding<LocalState>(
    get: @escaping (State) -> LocalState,
    send localStateToViewAction: @escaping (LocalState) -> Action
  ) -> Binding<LocalState> {
    ObservedObject(wrappedValue: self)
      .projectedValue[get: .init(rawValue: get), send: .init(rawValue: localStateToViewAction)]
  }

  public func binding<LocalState>(
    get: @escaping (State) -> LocalState,
    send action: Action
  ) -> Binding<LocalState> {
    self.binding(get: get, send: { _ in action })
  }

  public func binding(
    send localStateToViewAction: @escaping (State) -> Action
  ) -> Binding<State> {
    self.binding(get: { $0 }, send: localStateToViewAction)
  }

  public func binding(send action: Action) -> Binding<State> {
    self.binding(send: { _ in action })
  }
  
  private subscript<LocalState>(
    get state: HashableWrapper<(State) -> LocalState>,
    send action: HashableWrapper<(LocalState) -> Action>
  ) -> LocalState {
    get { state.rawValue(self.state) }
    set { self.send(action.rawValue(newValue)) }
  }
}

extension ViewStore where State: Equatable {
  public convenience init(_ store: Store<State, Action>) {
    self.init(store, removeDuplicates: ==)
  }
}

extension ViewStore where State == Void {
  public convenience init(_ store: Store<Void, Action>) {
    self.init(store, removeDuplicates: ==)
  }
}

@dynamicMemberLookup
public struct StorePublisher<State>: Publisher {
  public typealias Output = State
  public typealias Failure = Never
  
  public let upstream: AnyPublisher<State, Never>
  public let viewStore: Any
  
  fileprivate init<Action>(viewStore: ViewStore<State, Action>) {
    self.viewStore = viewStore
    self.upstream = viewStore._state.eraseToAnyPublisher()
  }
  
  public func receive<S>(subscriber: S)
  where S: Subscriber, Failure == S.Failure, Output == S.Input {
    self.upstream.subscribe(
      AnySubscriber(
        receiveSubscription: subscriber.receive(subscription:),
        receiveValue: subscriber.receive(_:),
        receiveCompletion: { [viewStore = self.viewStore] in
          subscriber.receive(completion: $0)
          _ = viewStore
        }
      )
    )
  }
  
  private init<P>(
    upstream: P,
    viewStore: Any
  ) where P: Publisher, Failure == P.Failure, Output == P.Output {
    self.upstream = upstream.eraseToAnyPublisher()
    self.viewStore = viewStore
  }
  
  public subscript<LocalState>(
    dynamicMember keyPath: KeyPath<State, LocalState>
  ) -> StorePublisher<LocalState>
  where LocalState: Equatable {
    .init(upstream: self.upstream.map(keyPath).removeDuplicates(), viewStore: self.viewStore)
  }
}

private struct HashableWrapper<Value>: Hashable {
  let rawValue: Value
  static func == (lhs: Self, rhs: Self) -> Bool { false }
  func hash(into hasher: inout Hasher) {}
}
