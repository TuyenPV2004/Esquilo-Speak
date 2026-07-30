package com.esquilospeak.advancedlearning;

public interface MediaDeliveryPort {

    MediaAsset load(String mediaId);

    record MediaAsset(byte[] bytes, String contentType, String checksum) {
        public MediaAsset {
            bytes = bytes.clone();
        }

        @Override
        public byte[] bytes() {
            return bytes.clone();
        }
    }
}
