package vn.antam.medication;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.awt.image.BufferedImage;
import java.io.ByteArrayOutputStream;
import java.io.DataOutputStream;
import java.io.IOException;
import java.util.zip.CRC32;

import javax.imageio.ImageIO;

import org.junit.jupiter.api.Test;

import vn.antam.common.ApiException;

class ImageStoreTest {

    /** A PNG of a few dozen bytes whose header claims 50,000 × 50,000 pixels (10 GB once decoded). */
    private static byte[] hugePngHeader() throws IOException {
        ByteArrayOutputStream bytes = new ByteArrayOutputStream();
        DataOutputStream out = new DataOutputStream(bytes);
        out.write(new byte[]{(byte) 0x89, 'P', 'N', 'G', '\r', '\n', 0x1A, '\n'});
        ByteArrayOutputStream ihdr = new ByteArrayOutputStream();
        DataOutputStream d = new DataOutputStream(ihdr);
        d.writeBytes("IHDR");
        d.writeInt(50_000);
        d.writeInt(50_000);
        d.write(new byte[]{8, 2, 0, 0, 0}); // 8-bit RGB
        byte[] chunk = ihdr.toByteArray();
        out.writeInt(13);
        out.write(chunk);
        CRC32 crc = new CRC32();
        crc.update(chunk);
        out.writeInt((int) crc.getValue());
        return bytes.toByteArray();
    }

    @Test
    void aSmallFileClaimingAHugeImageIsRefusedBeforeDecoding() throws IOException {
        byte[] file = hugePngHeader();
        assertThat(file.length).isLessThan(100);
        assertThatThrownBy(() -> ImageStore.decode(file))
                .isInstanceOf(ApiException.class)
                .hasMessageContaining("độ phân giải quá lớn");
    }

    @Test
    void anOrdinaryPhotoStillDecodes() throws IOException {
        ByteArrayOutputStream png = new ByteArrayOutputStream();
        ImageIO.write(new BufferedImage(40, 30, BufferedImage.TYPE_INT_RGB), "png", png);
        BufferedImage image = ImageStore.decode(png.toByteArray());
        assertThat(image.getWidth()).isEqualTo(40);
        assertThat(image.getHeight()).isEqualTo(30);
    }

    @Test
    void textIsNotAnImage() {
        assertThatThrownBy(() -> ImageStore.decode("xin chào".getBytes()))
                .isInstanceOf(ApiException.class)
                .hasMessageContaining("không phải ảnh");
    }
}
