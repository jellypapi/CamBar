# CamBar

CamBar is a small macOS menu bar viewer for local RTSP camera streams.

It is built for quick checks while working: click the menu bar icon, glance at the live preview, adjust volume or mute, then get back to work.

## Features

- macOS menu bar camera preview
- Multiple camera tabs
- Add/remove camera tabs from the preview
- Editable RTSP URL per tab
- Keep preview stream alive between opens
- Mute, volume, play, and reconnect controls in the preview
- No Dock icon

## Tapo RTSP Setup

Most Tapo cameras expose RTSP only after a local camera account is configured in the Tapo app.

1. Open the Tapo app.
2. Select the camera.
3. Open camera settings.
4. Find `Advanced Settings` or `Camera Account`.
5. Create a camera account username and password.
6. Keep the camera on the same local network as your Mac.
7. Give the camera a stable IP address from your router or Tapo network settings.

Then use one of these RTSP URLs:

```text
rtsp://USERNAME:PASSWORD@CAMERA_IP:554/stream1
rtsp://USERNAME:PASSWORD@CAMERA_IP:554/stream2
```

Commonly:

- `stream1` is the main, higher-quality stream.
- `stream2` is the lower-resolution stream and is often faster for previews.

Example:

```text
rtsp://babycam:your-password@192.168.0.45:554/stream1
```

If the URL works in VLC, it should work in CamBar.

TP-Link reference: [How to view Tapo camera on a PC through RTSP stream](https://www.tp-link.com/support/faq/2680/)

## Using CamBar

1. Build and open the app.
2. Click the baby-face icon in the macOS menu bar.
3. Paste an RTSP URL into the field.
4. Press play.
5. Use `+` to add another camera tab.
6. Use the `x` inside a tab to remove it.

The app saves camera tabs, RTSP URLs, mute state, volume, selected tab, and preview keep-alive behavior in local macOS app preferences.

## Build

```bash
pod install
chmod +x scripts/build_app.sh
scripts/build_app.sh
open build/Manual/CamBar.app
```

You can also open `CamBar.xcworkspace` in Xcode after running `pod install`, but `scripts/build_app.sh` is the reliable local build path right now.

## Downloaded Builds

GitHub Release builds are ad-hoc signed and are not Apple-notarized yet.

On first launch, macOS may block the app because it was downloaded from the internet and is not notarized. Use Finder's right-click `Open` flow if you trust the downloaded build, or build locally from source.

## Development Notes

- The app uses VLCKit for RTSP playback.
- Preview playback is managed in `CameraPopoverViewController`.
- Playback controls live in the menu bar preview.
- The menu bar preview uses a non-activating panel, with explicit text-field focus handling so URL editing and paste work.

## Privacy

CamBar connects directly to RTSP URLs on your local network. It does not require a cloud login and does not send your camera credentials to a server.

## License

CamBar's own source code is licensed under the MIT License.

CamBar uses VLCKit for RTSP playback. The bundled VLCKit framework is licensed under the GNU Lesser General Public License version 2.1. See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) and [ThirdPartyLicenses/VLCKit-LGPL-2.1.txt](ThirdPartyLicenses/VLCKit-LGPL-2.1.txt).

The release app bundles VLCKit as an unmodified dynamic framework and includes the VLCKit LGPL license text in the app resources. This is not legal advice; verify license obligations before commercial redistribution.
