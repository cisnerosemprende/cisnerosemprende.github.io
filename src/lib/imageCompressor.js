// =========================================================================
// Compresor de Imágenes en Cliente (Canvas API)
// Optimizado para reducir peso de fotos antes de subir a Supabase Storage
// =========================================================================

/**
 * Comprime un archivo File/Blob de imagen en el navegador
 * @param {File} file - Archivo original
 * @param {Object} options - { maxWidth, maxHeight, quality }
 * @returns {Promise<Blob>} Blob comprimido en formato WebP / JPEG
 */
export async function compressImage(file, options = {}) {
  const {
    maxWidth = 1200,
    maxHeight = 1200,
    quality = 0.8,
    mimeType = 'image/webp'
  } = options;

  return new Promise((resolve, reject) => {
    const img = new Image();
    const reader = new FileReader();

    reader.onload = (e) => {
      img.src = e.target.result;
    };

    reader.onerror = (err) => reject(err);

    img.onload = () => {
      let width = img.width;
      let height = img.height;

      // Calcular proporción de escala
      if (width > maxWidth || height > maxHeight) {
        if (width / height > maxWidth / maxHeight) {
          height = Math.round((height * maxWidth) / width);
          width = maxWidth;
        } else {
          width = Math.round((width * maxHeight) / height);
          maxHeight;
          height = maxHeight;
        }
      }

      const canvas = document.createElement('canvas');
      canvas.width = width;
      canvas.height = height;

      const ctx = canvas.getContext('2d');
      ctx.drawImage(img, 0, 0, width, height);

      canvas.toBlob(
        (blob) => {
          if (!blob) {
            reject(new Error('Error al comprimir la imagen en canvas'));
            return;
          }
          console.log(`[Compresión] Original: ${(file.size / 1024).toFixed(1)} KB -> Comprimido: ${(blob.size / 1024).toFixed(1)} KB`);
          resolve(blob);
        },
        mimeType,
        quality
      );
    };

    img.onerror = (err) => reject(err);
    reader.readAsDataURL(file);
  });
}
