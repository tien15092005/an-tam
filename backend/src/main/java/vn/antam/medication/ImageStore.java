package vn.antam.medication;

import java.awt.Graphics2D;
import java.awt.RenderingHints;
import java.awt.image.BufferedImage;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.UncheckedIOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.HexFormat;
import java.util.Iterator;
import java.util.UUID;

import javax.imageio.IIOImage;
import javax.imageio.ImageIO;
import javax.imageio.ImageReadParam;
import javax.imageio.ImageReader;
import javax.imageio.stream.ImageInputStream;
import javax.imageio.ImageWriteParam;
import javax.imageio.ImageWriter;
import javax.imageio.stream.ImageOutputStream;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import vn.antam.common.ApiException;

/**
 * Stores medication photos on disk (a Docker volume in compose). Every upload is decoded and
 * re-encoded as JPEG: that rejects anything that is not a real image, drops EXIF metadata
 * (GPS location, phone model) and caps the size the elder's phone has to download.
 */
@Component
public class ImageStore {

    static final int MAX_UPLOAD_BYTES = 5 * 1024 * 1024;
    private static final int MAX_EDGE = 1600;
    /** A phone photo is 12–50 MP. Anything bigger is refused before decoding, so a tiny file that claims to be
     * 50,000 × 50,000 px cannot make the server allocate gigabytes. */
    static final long MAX_PIXELS = 60_000_000L;

    private final Path root;

    public ImageStore(@Value("${antam.media.dir:./data/media}") String dir) {
        this.root = Path.of(dir).toAbsolutePath().normalize();
        try {
            Files.createDirectories(root);
        } catch (IOException e) {
            throw new UncheckedIOException("Cannot create media directory " + root, e);
        }
    }

    public record Stored(String key, String mimeType, int sizeBytes, String sha256) {
    }

    public Stored save(byte[] upload) {
        if (upload == null || upload.length == 0) throw ApiException.badRequest("empty_file", "Chưa chọn ảnh.");
        if (upload.length > MAX_UPLOAD_BYTES) throw ApiException.badRequest("file_too_large", "Ảnh quá lớn (tối đa 5 MB).");
        BufferedImage image = decode(upload);
        byte[] jpeg = toJpeg(scaleDown(image));
        String key = UUID.randomUUID() + ".jpg";
        try {
            Files.write(resolve(key), jpeg);
        } catch (IOException e) {
            throw new UncheckedIOException(e);
        }
        return new Stored(key, "image/jpeg", jpeg.length, sha256(jpeg));
    }

    /** Reads the size from the header first, then decodes, skipping pixels when the photo is far larger than needed. */
    static BufferedImage decode(byte[] upload) {
        try (ImageInputStream in = ImageIO.createImageInputStream(new ByteArrayInputStream(upload))) {
            Iterator<ImageReader> readers = in == null ? null : ImageIO.getImageReaders(in);
            if (readers == null || !readers.hasNext()) throw notAnImage();
            ImageReader reader = readers.next();
            try {
                reader.setInput(in, true, true);
                long w = reader.getWidth(0);
                long h = reader.getHeight(0);
                if (w <= 0 || h <= 0) throw notAnImage();
                if (w * h > MAX_PIXELS) {
                    throw ApiException.badRequest("image_too_large", "Ảnh có độ phân giải quá lớn. Hãy chụp lại bằng camera thường.");
                }
                ImageReadParam param = reader.getDefaultReadParam();
                int step = (int) Math.max(1, Math.max(w, h) / (MAX_EDGE * 2L));
                if (step > 1) param.setSourceSubsampling(step, step, 0, 0);
                BufferedImage image = reader.read(0, param);
                if (image == null) throw notAnImage();
                return image;
            } finally {
                reader.dispose();
            }
        } catch (IOException | RuntimeException e) {
            if (e instanceof ApiException api) throw api;
            throw notAnImage();
        }
    }

    private static ApiException notAnImage() {
        return ApiException.badRequest("not_an_image", "Tệp không phải ảnh JPEG hoặc PNG.");
    }

    public byte[] read(String key) {
        try {
            return Files.readAllBytes(resolve(key));
        } catch (IOException e) {
            throw ApiException.notFound("ảnh");
        }
    }

    /** Removes the file of a photo deleted long enough ago; already gone is fine. */
    public boolean delete(String key) {
        try {
            return Files.deleteIfExists(resolve(key));
        } catch (IOException | ApiException e) {
            return false;
        }
    }

    private Path resolve(String key) {
        Path p = root.resolve(key).normalize();
        if (!p.startsWith(root)) throw ApiException.notFound("ảnh"); // never escape the media folder
        return p;
    }

    private static BufferedImage scaleDown(BufferedImage src) {
        int w = src.getWidth();
        int h = src.getHeight();
        double scale = Math.min(1.0, (double) MAX_EDGE / Math.max(w, h));
        int nw = Math.max(1, (int) Math.round(w * scale));
        int nh = Math.max(1, (int) Math.round(h * scale));
        // Always redraw onto an RGB canvas: removes alpha (PNG) that JPEG cannot hold.
        BufferedImage out = new BufferedImage(nw, nh, BufferedImage.TYPE_INT_RGB);
        Graphics2D g = out.createGraphics();
        g.setRenderingHint(RenderingHints.KEY_INTERPOLATION, RenderingHints.VALUE_INTERPOLATION_BILINEAR);
        g.setColor(java.awt.Color.WHITE);
        g.fillRect(0, 0, nw, nh);
        g.drawImage(src, 0, 0, nw, nh, null);
        g.dispose();
        return out;
    }

    private static byte[] toJpeg(BufferedImage image) {
        ImageWriter writer = ImageIO.getImageWritersByFormatName("jpeg").next();
        ImageWriteParam param = writer.getDefaultWriteParam();
        param.setCompressionMode(ImageWriteParam.MODE_EXPLICIT);
        param.setCompressionQuality(0.85f);
        ByteArrayOutputStream bytes = new ByteArrayOutputStream();
        try (ImageOutputStream out = ImageIO.createImageOutputStream(bytes)) {
            writer.setOutput(out);
            writer.write(null, new IIOImage(image, null, null), param);
        } catch (IOException e) {
            throw new UncheckedIOException(e);
        } finally {
            writer.dispose();
        }
        return bytes.toByteArray();
    }

    private static String sha256(byte[] data) {
        try {
            return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(data));
        } catch (NoSuchAlgorithmException e) {
            throw new IllegalStateException(e);
        }
    }
}
