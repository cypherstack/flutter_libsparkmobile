import 'package:flutter_libsparkmobile/flutter_libsparkmobile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mnemonic to address test', () async {
    // Generate key data from the mnemonic.
    //
    // The plugin integration test includes using the bip39 and coinlib packages
    // to generate the key data from the mnemonic.  Instead we will just use
    // a hard-coded key data hex string here in order to avoid unnecessary
    // dependencies.
    //
    // This keyData is derived from the mnemonic `jazz settle broccoli dove hurt
    // deny leisure coffee ivory calm pact chicken flag spot nature gym afford
    // cotton dinosaur young private flash core approve` at the firo-cli's
    // standard derivation path m/44'/136'/0'/6/1.
    const keyDataHex =
        'cb02b05c71a69080b083484f1cdf407677fac00ced6438df16925e2a29b4eebf';

    // Derive the address from the key data.
    final address = await LibSpark.getAddress(
      privateKey: keyDataHex.toBytes32(),
      index: 1,
      diversifier: 0,
      isTestNet: false,
    );

    // Define the expected address.
    const expectedAddress =
        'sm1shqukway59rq5nefgywyrrmmt8eswgjqdgnsdn4ysrsfl2rna60l2drelf6nfe0pamyxh3w8ypa7y35znhf4c6w44d7lw8xu3kjra4sg2v0zn508hawuul5596fm2h4e2csa9egk4ks3a';

    // Compare the derived address with the expected address.
    expect(address, expectedAddress);
  });
}
