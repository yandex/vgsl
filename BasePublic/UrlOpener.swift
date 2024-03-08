// Copyright 2017 Yandex LLC. All rights reserved.

import Foundation

public typealias UrlOpener = (URL) -> Void

public typealias URLAsyncOpener = (URL, @escaping ResultAction<Bool>) -> Void
