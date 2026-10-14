/// Nothing to claim: the operating system hands a `clash://` link to the
/// desktop this panel talks to, which registered itself long before it did.
class Protocol {
  void register(String scheme) {}

  Future<void> registerLinux(List<String> schemes) async {}
}

final protocol = Protocol();
