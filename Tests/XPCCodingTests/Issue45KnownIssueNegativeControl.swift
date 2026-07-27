import Testing

@Test
func issue45KnownIssueNegativeControl() {
  withKnownIssue {
    #expect(Bool(false))
  }
}
