# DevCam FAQ

Status: Answers reflect current behavior.

## Does DevCam upload my recordings?
No. DevCam does not send data to the internet and stores everything locally.

## How long does DevCam keep recordings?
The rolling buffer keeps the last 15 minutes of screen activity. Saved clips
remain until you delete them.

## Can I save clips other than 5, 10, or 15 minutes?
Yes. The menubar Save Clip slider supports 1-15 minute exports in 1-minute steps.
The Advanced option lets you set a custom start/end range within the buffer.

## Can I change the buffer length?
Not yet. The buffer is fixed at 15 minutes in current builds.

## Can I change recording quality?
Yes. Preferences → General lets you choose Low (720p), Medium (1080p), or High
(native resolution). Changes apply after restart.

## Where are buffer files stored?
`~/Library/Application Support/DevCam/buffer/`

## How do I reset permissions?
System Settings > Privacy and Security > Screen Recording.

## Does DevCam record audio?
No. Current builds capture screen video only.

## Can I record a specific display?
Not yet. DevCam records the primary display (largest resolution) in current builds.

## Why is export slower on older Macs?
Encoding and disk speed are the main factors. Older GPUs may take longer.

## Can I pause recording?
Not currently. Recording only pauses on system sleep and resumes on wake.

## Can I record longer than 15 minutes?
Not yet. Current builds only support saving the last 5, 10, or 15 minutes.
Forward recording and longer clips are planned.

## Is DevCam open source?
Not yet. The repository will be public on GitHub (coming soon).

## What happens if I quit DevCam?
Recording stops. Buffer files remain on disk until overwritten on the next run
or deleted manually.

## How much disk space does DevCam use?
Plan for about 2 GB of free disk space for a full 15-minute buffer at 60fps.
Actual usage varies by resolution and bitrate.
