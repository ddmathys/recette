const MAX_DIMENSION = 2400;

/**
 * Downscales and re-encodes an image client-side so it fits under maxBytes.
 * Non-image files, or files already under the limit, are returned untouched.
 */
export async function compressImageIfNeeded(file: File, maxBytes: number): Promise<File> {
  if (!file.type.startsWith("image/") || file.size <= maxBytes) return file;

  const bitmap = await createImageBitmap(file).catch(() => null);
  if (!bitmap) return file;

  let { width, height } = bitmap;
  const scale = Math.min(1, MAX_DIMENSION / Math.max(width, height));
  width = Math.round(width * scale);
  height = Math.round(height * scale);

  const canvas = document.createElement("canvas");
  canvas.width = width;
  canvas.height = height;
  const ctx = canvas.getContext("2d");
  if (!ctx) return file;
  ctx.drawImage(bitmap, 0, 0, width, height);

  let quality = 0.9;
  for (let attempt = 0; attempt < 6; attempt++) {
    const blob = await new Promise<Blob | null>((resolve) => canvas.toBlob(resolve, "image/jpeg", quality));
    if (!blob) return file;
    if (blob.size <= maxBytes || quality <= 0.4) {
      const name = file.name.replace(/\.\w+$/, "") + ".jpg";
      return new File([blob], name, { type: "image/jpeg" });
    }
    quality -= 0.15;
  }
  return file;
}
