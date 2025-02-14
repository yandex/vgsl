// Copyright 2021 Yandex LLC. All rights reserved.

/// Closure with no parameters and no return value.
public typealias Action = () -> Void
/// Closure with no parameters and no return value, executed on the
/// main actor.
public typealias MainActorAction = @MainActor () -> Void
/// Sendable closure with no parameters and no return value.
public typealias SendableAction = @Sendable () -> Void
public typealias ResultAction<T> = (_ result: T) -> Void
public typealias AsyncAction = (_ completion: @escaping Action) -> Void
public typealias AsyncResultAction<T> = (_ completion: @escaping (_ result: T) -> Void) -> Void
public typealias AsyncResultVoidAction = (_ completion: @escaping () -> Void) -> Void
public typealias AsyncRequest<Arg, Res> =
  (_ arg: Arg, _ completion: @escaping (_ result: Res) -> Void) -> Void
public typealias AsyncRequestWithSender<Arg, Sender, Res> =
  (_ arg: Arg, _ sender: Sender, _ completion: @escaping (_ result: Res) -> Void) -> Void
