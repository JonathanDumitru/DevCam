# ADR 0001: Segmented Rolling Buffer

Status: Accepted
Date: 2026-01-23

## Context
DevCam needs continuous recording with a bounded footprint and the ability to
export the last N minutes quickly. Trimming a single growing video file is
expensive and error prone.

## Decision
Record in fixed 60-second segments and keep the newest 15 segments on disk
(15-minute buffer). The buffer lives under
~/Library/Application Support/DevCam/buffer and BufferManager evicts the
oldest segment when the limit is exceeded. ClipExporter assembles exports by
stitching the selected segments.

## Consequences
- Fast exports by concatenating pre-encoded segments.
- Simple eviction logic keeps disk usage bounded.
- Many small files increase file-system churn and require stitching on export.

## Alternatives Considered
- Single rolling file with time-based trimming.
- In-memory buffering with periodic dumps to disk.
- Different segment durations (shorter for more granularity, longer for fewer files).
