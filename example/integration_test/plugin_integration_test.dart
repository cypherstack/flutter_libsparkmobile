import 'package:coinlib_flutter/coinlib_flutter.dart' as coinlib;
import 'package:flutter_libsparkmobile/flutter_libsparkmobile.dart';
import 'package:flutter_libsparkmobile_example/util/address_generator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Load coinlib for crypto operations.
  coinlib.loadCoinlib();

  testWidgets('derive keydata', (WidgetTester tester) async {
    // Define the mnemonic.
    const mnemonic =
        'jazz settle broccoli dove hurt deny leisure coffee ivory calm pact chicken flag spot nature gym afford cotton dinosaur young private flash core approve';

    const index = 1;

    // Construct derivePath string.
    const derivePath = "m/44'/1'/0'/$kSparkChain/$index";

    // Generate key data from the mnemonic.
    final keyDataHex =
        await SparkAddressGenerator.generateKeyData(mnemonic, derivePath);

    // Define the expected key.
    const expectedKey =
        'a5381ccbbf0b068447d349aa98adadd81333467a5821784d0048c1fe9cc77504';

    // Compare the derived key with the expected one.
    expect(keyDataHex, expectedKey);
  });

  testWidgets('mnemonic to address test mainnet', (WidgetTester tester) async {
    // Define the mnemonic.
    const mnemonic =
        'jazz settle broccoli dove hurt deny leisure coffee ivory calm pact chicken flag spot nature gym afford cotton dinosaur young private flash core approve';

    const index = 1;

    // Construct derivePath string.
    const derivePath = "m/44'/136'/0'/$kSparkChain/$index";

    // Generate key data from the mnemonic.
    final keyDataHex =
        await SparkAddressGenerator.generateKeyData(mnemonic, derivePath);

    // Derive the address from the key data.
    final address =
        await SparkAddressGenerator.getAddress(keyDataHex, index, 0, false);

    // Define the expected address.
    const expectedAddress =
        'sm1shqukway59rq5nefgywyrrmmt8eswgjqdgnsdn4ysrsfl2rna60l2drelf6nfe0pamyxh3w8ypa7y35znhf4c6w44d7lw8xu3kjra4sg2v0zn508hawuul5596fm2h4e2csa9egk4ks3a';

    // Compare the derived address with the expected address.
    expect(address, expectedAddress);
  });

  testWidgets('mnemonic to address test testnet', (WidgetTester tester) async {
    // Define the mnemonic.
    const mnemonic =
        'jazz settle broccoli dove hurt deny leisure coffee ivory calm pact chicken flag spot nature gym afford cotton dinosaur young private flash core approve';

    const index = 1;

    // Construct derivePath string.
    const derivePath = "m/44'/1'/0'/$kSparkChain/$index";

    // Generate key data from the mnemonic.
    final keyDataHex =
        await SparkAddressGenerator.generateKeyData(mnemonic, derivePath);

    // Derive the address from the key data.
    final address =
        await SparkAddressGenerator.getAddress(keyDataHex, index, 0, true);

    // Define the expected address.
    const expectedAddress =
        'st132sxql5h6sv7eggh8mll5v9qkharn3e5a4v4n003jc5s7a07x32ntm2fq6uejk76a96xrh77hvlxhnfs926sqdg6pda9z50wlu86lyukpw47wrx47qvmnhmvue2mvm75apj7xhg6rhhqv';

    // Compare the derived address with the expected address.
    expect(address, expectedAddress);
  });

  // TODO fix when memo changes are added to firo core
  // test('identify coin', () async {
  //   // Define the mnemonic.
  //   const mnemonic =
  //       'jazz settle broccoli dove hurt deny leisure coffee ivory calm pact chicken flag spot nature gym afford cotton dinosaur young private flash core approve';
  //
  //   const index = 1;
  //
  //   // Construct derivePath string.
  //   const derivePath = "m/44'/1'/0'/$kSparkChain/$index";
  //
  //   // Generate key data from the mnemonic.
  //   final keyDataHex =
  //       await SparkAddressGenerator.generateKeyData(mnemonic, derivePath);
  //
  //   // A serialized coin produced by firo-qt with the `jazz settle...` mnemonic.
  //   //
  //   // See tx 640e4a0016a5802d57be4fe212c398cd107ff81b55b02b79dac0a133528fadd3.
  //   const serializedCoin =
  //       "AAYgxtq4T3i1KH5fgrtb/FjWK0v2TX2eDX9K0dQEJqzjAQCEFvHR39VYxiAeBSugNRfkLytkBwHkHnfbbYeVtPK7PAAAkjacXJtxgT/j5pYB+HBQBBEWvTlJwF+tQh7Q4HIQB9QBAFIuZMbFIWSzhuA+4sYx+uPB+6i1VTXG4VyuWDJM5eKxmkeZllxQMvx/s0JYBWPXW+4J9QDA233bR68p3TG4HYS7ZwF3kMyQoB9w/I8hVJUq5uKzEGXKxs615pqxwNHKCAgKUykguw58PkTRN1Gbdxk+LAydUW83BHj4vb8iPj/nDGNMI1TADs0dAAAAANOtj1IzocDaeSuwVRv4fxDNmMMS4k++Vy2ApRYASg5k";
  //
  //   // TODO: get test vector
  //   final context = Uint8List(0);
  //
  //   // Identify the coin.
  //   final coin = LibSpark.identifyAndRecoverCoin(
  //     serializedCoin,
  //     privateKeyHex: keyDataHex,
  //     index: index,
  //     context: context,
  //     isTestNet: true,
  //   );
  //
  //   expect(coin, isNotNull);
  // });

  group("Address validation", () {
    test('valid mainnet address', () async {
      const address =
          'sm1shqukway59rq5nefgywyrrmmt8eswgjqdgnsdn4ysrsfl2rna60l2drelf6nfe0pamyxh3w8ypa7y35znhf4c6w44d7lw8xu3kjra4sg2v0zn508hawuul5596fm2h4e2csa9egk4ks3a';

      expect(
        LibSpark.validateAddress(
          address: address,
          isTestNet: false,
        ),
        true,
      );
      expect(
        LibSpark.validateAddress(
          address: address,
          isTestNet: true,
        ),
        false,
      );
    });

    test('valid testnet address', () async {
      const address =
          'st132sxql5h6sv7eggh8mll5v9qkharn3e5a4v4n003jc5s7a07x32ntm2fq6uejk76a96xrh77hvlxhnfs926sqdg6pda9z50wlu86lyukpw47wrx47qvmnhmvue2mvm75apj7xhg6rhhqv';

      expect(
        LibSpark.validateAddress(
          address: address,
          isTestNet: true,
        ),
        true,
      );
      expect(
        LibSpark.validateAddress(
          address: address,
          isTestNet: false,
        ),
        false,
      );
    });

    test('invalid address', () async {
      const address = 'something';

      expect(
        LibSpark.validateAddress(
          address: address,
          isTestNet: true,
        ),
        false,
      );
      expect(
        LibSpark.validateAddress(
          address: address,
          isTestNet: false,
        ),
        false,
      );
    });
  });

  test('hash tag from x and y', () async {
    const x =
        '805f27cb4b6b8958587772011606a1fe264eb5cab0140dfc79d53f041d179647';
    const y =
        '52e22e74a5b57de0bb661a8116b06de8c3e70dc15a3865dea9a56a0288771c0d';

    expect(
      LibSpark.hashTag(x, y),
      '875a3d3fe398ba1084ef68679baa81980ba3448c145afad725a9588c2f7fcfcf',
    );
  });
}
