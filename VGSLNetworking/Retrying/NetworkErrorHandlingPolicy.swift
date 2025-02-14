// Copyright 2018 Yandex LLC. All rights reserved.

public enum NetworkErrorHandlingPolicy: Sendable {
  case complete
  case waitForRetry
}
