#!/bin/bash
# Generates testset/ — synthetic photos with controlled metadata for the
# Lightroom smoke test described in TESTPLAN.md. macOS only (uses sips);
# EXIF is written with the ExifTool bundled in 3rd/exiftool.
#
# All photos share the same camera metadata; the capture date separates the
# duplicate groups. Run from anywhere: ./test/make_testset.sh
set -euo pipefail
cd "$(dirname "$0")/.."

ET=3rd/exiftool/exiftool
SRC=creatives/preview1.png
OUT=testset

rm -rf "$OUT"
mkdir -p "$OUT"

# jpg <file> <pixels> — create a JPG from the source image
jpg() {
	sips -s format jpeg -z "$2" "$2" "$SRC" --out "$OUT/$1" >/dev/null
}

# meta <file> <minute> [extra exiftool args...] — write the common EXIF set;
# the minute makes each pair's capture date unique
meta() {
	local f="$OUT/$1" minute="$2"
	shift 2
	"$ET" -overwrite_original -q \
		-Make="TeekesselchenTest" -Model="TestCam" -SerialNumber="TK001" \
		-LensModel="TK 50mm F1.8" -ISO=100 -ExposureTime="1/125" -FNumber=8 \
		-ExposureCompensation=0 \
		-DateTimeOriginal="2020:01:01 10:${minute}:00" \
		-CreateDate="2020:01:01 10:${minute}:00" \
		"$@" "$f"
}

# heic <jpg> <heic> — convert, EXIF is preserved by sips
heic() {
	sips -s format heic "$OUT/$1" --out "$OUT/$2" >/dev/null
}

echo "pair01: exact JPG duplicates (default rules must group them)"
jpg IMG_0101.jpg 800
meta IMG_0101.jpg 01
cp "$OUT/IMG_0101.jpg" "$OUT/IMG_0102.jpg"

echo "pair02: HEIC/JPG twins, same base name (file name rule + prefer HEIC)"
jpg IMG_0201.jpg 800
meta IMG_0201.jpg 02
heic IMG_0201.jpg IMG_0201.heic

echo "pair03: same photo, file sizes differ by a few bytes (file size rule)"
jpg IMG_0301.jpg 800
meta IMG_0301.jpg 03
cp "$OUT/IMG_0301.jpg" "$OUT/IMG_0302.jpg"
"$ET" -overwrite_original -q -Comment="padding-padding-padding-padding-padding" "$OUT/IMG_0302.jpg"

echo "pair04: two identical HEICs (format tie must fall through to rating)"
jpg IMG_0401_tmp.jpg 800
meta IMG_0401_tmp.jpg 04
heic IMG_0401_tmp.jpg IMG_0401.heic
cp "$OUT/IMG_0401.heic" "$OUT/IMG_0402.heic"
rm "$OUT/IMG_0401_tmp.jpg"

echo "burst: three shots in the same second, different subseconds (issue #6)"
jpg IMG_0501.jpg 800
meta IMG_0501.jpg 05 -SubSecTime=100 -SubSecTimeOriginal=100 -SequenceNumber=1
cp "$OUT/IMG_0501.jpg" "$OUT/IMG_0502.jpg"
cp "$OUT/IMG_0501.jpg" "$OUT/IMG_0503.jpg"
"$ET" -overwrite_original -q -SubSecTime=400 -SubSecTimeOriginal=400 -SequenceNumber=2 "$OUT/IMG_0502.jpg"
"$ET" -overwrite_original -q -SubSecTime=700 -SubSecTimeOriginal=700 -SequenceNumber=3 "$OUT/IMG_0503.jpg"

echo "pair06: same photo in two resolutions (prefer higher dimension)"
jpg IMG_0601.jpg 1200
meta IMG_0601.jpg 06
jpg IMG_0602.jpg 600
meta IMG_0602.jpg 06

echo "pair07: exact duplicates for the picked-flag tests (issues #7/#8)"
jpg IMG_0701.jpg 800
meta IMG_0701.jpg 07
cp "$OUT/IMG_0701.jpg" "$OUT/IMG_0702.jpg"

echo "control: unique photo that must never be marked"
jpg IMG_0801.jpg 800
meta IMG_0801.jpg 08

echo
echo "Generated $(ls "$OUT" | wc -l | tr -d ' ') files in $OUT/:"
"$ET" -q -T -FileName -DateTimeOriginal -SubSecTimeOriginal -FileSize -ImageSize -FileType "$OUT"
