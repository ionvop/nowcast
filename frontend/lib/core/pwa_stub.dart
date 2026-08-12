// Native/no-op targets for the conditional PWA install import.

void pwaInit(void Function() onAvailable, void Function() onInstalled) {
  // no-op on native
}

Future<void> pwaPromptInstall() async {
  // no-op on native
}