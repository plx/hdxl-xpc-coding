import Testing

@Test("CI negative control")
func ciNegativeControl() {
  #expect(Bool(false), "Deliberate failure proving that CI rejects a failing unit test.")
}
