package com.refrigerator.app.dto;

import java.util.List;

public class ScanResponseDto {
    private List<String> recognizedIngredients;
    private String rawResponse;

    public ScanResponseDto() {}

    public ScanResponseDto(List<String> recognizedIngredients, String rawResponse) {
        this.recognizedIngredients = recognizedIngredients;
        this.rawResponse = rawResponse;
    }

    public List<String> getRecognizedIngredients() { return recognizedIngredients; }
    public void setRecognizedIngredients(List<String> recognizedIngredients) { this.recognizedIngredients = recognizedIngredients; }
    public String getRawResponse() { return rawResponse; }
    public void setRawResponse(String rawResponse) { this.rawResponse = rawResponse; }

    public static Builder builder() { return new Builder(); }

    public static class Builder {
        private List<String> recognizedIngredients;
        private String rawResponse;

        public Builder recognizedIngredients(List<String> recognizedIngredients) { this.recognizedIngredients = recognizedIngredients; return this; }
        public Builder rawResponse(String rawResponse) { this.rawResponse = rawResponse; return this; }

        public ScanResponseDto build() {
            return new ScanResponseDto(recognizedIngredients, rawResponse);
        }
    }
}
