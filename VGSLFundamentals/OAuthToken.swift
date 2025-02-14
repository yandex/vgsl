// Copyright 2019 Yandex LLC. All rights reserved.

public enum OAuthTokenTag: Sendable {}
public typealias OAuthToken = Tagged<OAuthTokenTag, String>
