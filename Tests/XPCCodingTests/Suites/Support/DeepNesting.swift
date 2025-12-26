
struct Deep1: Codable, Equatable {
  let value: Int
}

struct Deep2: Codable, Equatable {
  let value: Int
  let inner: Deep1
}

struct Deep3: Codable, Equatable {
  let value: Int
  let inner: Deep2
}

struct Deep4: Codable, Equatable {
  let value: Int
  let inner: Deep3
}

struct Deep5: Codable, Equatable {
  let value: Int
  let inner: Deep4
}

struct Deep6: Codable, Equatable {
  let value: Int
  let inner: Deep5
}

struct Deep7: Codable, Equatable {
  let value: Int
  let inner: Deep6
}

struct Deep8: Codable, Equatable {
  let value: Int
  let inner: Deep7
}

struct Deep9: Codable, Equatable {
  let value: Int
  let inner: Deep8
}

struct Deep10: Codable, Equatable {
  let value: Int
  let inner: Deep9
}

struct Deep11: Codable, Equatable {
  let value: Int
  let inner: Deep10
}

struct Deep12: Codable, Equatable {
  let value: Int
  let inner: Deep11
}

struct Deep13: Codable, Equatable {
  let value: Int
  let inner: Deep12
}

struct Deep14: Codable, Equatable {
  let value: Int
  let inner: Deep13
}

struct Deep15: Codable, Equatable {
  let value: Int
  let inner: Deep14
}

extension Deep15 {
  
  static let exampleValues: [Self] = [
    Deep15(
      value: 15,
      inner: Deep14(
        value: 14,
        inner: Deep13(
          value: 13,
          inner: Deep12(
            value: 12,
            inner: Deep11(
              value: 11,
              inner: Deep10(
                value: 10,
                inner: Deep9(
                  value: 9,
                  inner: Deep8(
                    value: 8,
                    inner: Deep7(
                      value: 7,
                      inner: Deep6(
                        value: 6,
                        inner: Deep5(
                          value: 5,
                          inner: Deep4(
                            value: 4,
                            inner: Deep3(
                              value: 3,
                              inner: Deep2(
                                value: 2,
                                inner: Deep1(value: 1)
                              )
                            )
                          )
                        )
                      )
                    )
                  )
                )
              )
            )
          )
        )
      )
    )
  ]
}
