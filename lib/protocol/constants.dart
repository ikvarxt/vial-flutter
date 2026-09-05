// SPDX-License-Identifier: GPL-2.0-or-later
const int cmdViaGetProtocolVersion = 0x01;
const int cmdViaGetKeyboardValue = 0x02;
const int cmdViaSetKeyboardValue = 0x03;
const int cmdViaGetKeycode = 0x04;
const int cmdViaSetKeycode = 0x05;
const int cmdViaLightingSetValue = 0x07;
const int cmdViaLightingGetValue = 0x08;
const int cmdViaLightingSave = 0x09;
const int cmdViaMacroGetCount = 0x0C;
const int cmdViaMacroGetBufferSize = 0x0D;
const int cmdViaMacroGetBuffer = 0x0E;
const int cmdViaMacroSetBuffer = 0x0F;
const int cmdViaGetLayerCount = 0x11;
const int cmdViaKeymapGetBuffer = 0x12;
const int cmdViaVialPrefix = 0xFE;
const int viaLayoutOptions = 0x02;
const int viaSwitchMatrixState = 0x03;
const int qmkBacklightBrightness = 0x09;
const int qmkBacklightEffect = 0x0A;
const int qmkRgblightBrightness = 0x80;
const int qmkRgblightEffect = 0x81;
const int qmkRgblightEffectSpeed = 0x82;
const int qmkRgblightColor = 0x83;
const int vialrgbGetInfo = 0x40;
const int vialrgbGetMode = 0x41;
const int vialrgbGetSupported = 0x42;
const int vialrgbSetMode = 0x41;
const int cmdVialGetKeyboardId = 0x00;
const int cmdVialGetSize = 0x01;
const int cmdVialGetDefinition = 0x02;
const int cmdVialGetEncoder = 0x03;
const int cmdVialSetEncoder = 0x04;
const int cmdVialGetUnlockStatus = 0x05;
const int cmdVialUnlockStart = 0x06;
const int cmdVialUnlockPoll = 0x07;
const int cmdVialLock = 0x08;
const int cmdVialQmkSettingsQuery = 0x09;
const int cmdVialQmkSettingsGet = 0x0A;
const int cmdVialQmkSettingsSet = 0x0B;
const int cmdVialQmkSettingsReset = 0x0C;
const int cmdVialDynamicEntryOp = 0x0D;
const int dynamicVialGetNumberOfEntries = 0x00;
const int dynamicVialTapDanceGet = 0x01;
const int dynamicVialTapDanceSet = 0x02;
const int dynamicVialComboGet = 0x03;
const int dynamicVialComboSet = 0x04;
const int dynamicVialKeyOverrideGet = 0x05;
const int dynamicVialKeyOverrideSet = 0x06;
const int dynamicVialAltRepeatKeyGet = 0x07;
const int dynamicVialAltRepeatKeySet = 0x08;

/// How much of a macro/keymap buffer we can read/write per packet.
const int bufferFetchChunk = 28;

const int vialProtocolAdvancedMacros = 2;
const int vialProtocolMatrixTester = 3;
const int vialProtocolDynamic = 4;
const int vialProtocolQmkSettings = 4;
const int vialProtocolExtMacros = 5;
const int vialProtocolKeyOverride = 5;

/// The example UIDs shipped with the vial-qmk template.
///
/// Kept as BigInt because dart2js cannot represent a full uint64.
final List<BigInt> exampleKeyboards = [
  BigInt.parse('D4A36200603E3007', radix: 16),
  BigInt.parse('32F62BC2EEF2237B', radix: 16),
  BigInt.parse('38CEA320F23046A5', radix: 16),
  BigInt.parse('BED2D31EC59A0BD8', radix: 16),
];
final BigInt exampleKeyboardPrefix = BigInt.parse('A6867BDFD3B00F', radix: 16);
final BigInt _prefixMask = BigInt.parse('FFFFFFFFFFFFFF', radix: 16);

bool isExampleKeyboardUid(BigInt uid) =>
    exampleKeyboards.contains(uid) ||
    (uid & _prefixMask) == exampleKeyboardPrefix;
