import XPCCoding

private func requireSendable<T: Sendable>(_: T) {}

func mutableFacadesAreNotSendable() {
  requireSendable(XPCEncoder())
  requireSendable(XPCDecoder())
}
