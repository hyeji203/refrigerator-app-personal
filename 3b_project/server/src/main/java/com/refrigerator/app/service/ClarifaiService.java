package com.refrigerator.app.service;

import com.refrigerator.app.dto.ScanResponseDto;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.reactive.function.client.WebClient;

import java.util.*;
import java.util.stream.Collectors;

@Service
public class ClarifaiService {

    @Value("${clarifai.api.key}")
    private String clarifaiApiKey;

    @Value("${gemini.api.key}")
    private String geminiApiKey;

    @Value("${gemini.api.url}")
    private String geminiApiUrl;

    private static final String CLARIFAI_API_URL = "https://api.clarifai.com";
    private static final String CLARIFAI_MODEL_ENDPOINT =
            "/v2/users/clarifai/apps/main/models/food-item-recognition/outputs";

    // 이 값 이상의 신뢰도를 가진 결과만 사용 (0.0 ~ 1.0)
    private static final double CONFIDENCE_THRESHOLD = 0.5;

    private final WebClient.Builder webClientBuilder;

    public ClarifaiService(WebClient.Builder webClientBuilder) {
        this.webClientBuilder = webClientBuilder;
    }

    /**
     * 1단계: Clarifai food-item-recognition으로 음식 인식 (영어 결과)
     * 2단계: Gemini로 영어 → 한국어 번역
     */
    public ScanResponseDto analyzeImage(MultipartFile imageFile) {
        try {
            String base64Image = Base64.getEncoder().encodeToString(imageFile.getBytes());

            // 1단계: Clarifai로 음식 인식
            List<String> englishIngredients = recognizeWithClarifai(base64Image);

            if (englishIngredients.isEmpty()) {
                return ScanResponseDto.builder()
                        .recognizedIngredients(new ArrayList<>())
                        .build();
            }

            // 2단계: Gemini로 한국어 번역
            List<String> koreanIngredients = translateToKorean(englishIngredients);

            return ScanResponseDto.builder()
                    .recognizedIngredients(koreanIngredients)
                    .build();

        } catch (Exception e) {
            throw new RuntimeException("이미지 분석 중 오류가 발생했습니다: " + e.getMessage());
        }
    }

    @SuppressWarnings("unchecked")
    private List<String> recognizeWithClarifai(String base64Image) {
        Map<String, Object> imageData = new HashMap<>();
        imageData.put("base64", base64Image);

        Map<String, Object> imageWrapper = new HashMap<>();
        imageWrapper.put("image", imageData);

        Map<String, Object> inputData = new HashMap<>();
        inputData.put("data", imageWrapper);

        Map<String, Object> requestBody = new HashMap<>();
        requestBody.put("inputs", List.of(inputData));

        WebClient webClient = webClientBuilder.baseUrl(CLARIFAI_API_URL).build();
        Map response = webClient.post()
                .uri(CLARIFAI_MODEL_ENDPOINT)
                .header("Authorization", "Key " + clarifaiApiKey)
                .header("Content-Type", "application/json")
                .bodyValue(requestBody)
                .retrieve()
                .bodyToMono(Map.class)
                .block();

        try {
            List<Map> outputs = (List<Map>) response.get("outputs");
            Map firstOutput = outputs.get(0);
            Map data = (Map) firstOutput.get("data");
            List<Map> concepts = (List<Map>) data.get("concepts");

            List<String> result = new ArrayList<>();
            for (Map concept : concepts) {
                double value = ((Number) concept.get("value")).doubleValue();
                if (value >= CONFIDENCE_THRESHOLD) {
                    result.add((String) concept.get("name"));
                }
            }
            return result;
        } catch (Exception e) {
            return new ArrayList<>();
        }
    }

    @SuppressWarnings("unchecked")
    private List<String> translateToKorean(List<String> englishNames) {
        String joined = String.join(", ", englishNames);

        String prompt =
                "다음 음식/식재료 이름 목록을 한국어로 번역해주세요.\n" +
                "규칙:\n" +
                "- 한국에서 일반적으로 사용하는 이름으로 번역하세요\n" +
                "- 쉼표(,)로만 구분해서 한 줄로 출력하세요\n" +
                "- 번역된 이름만 출력하고 다른 설명은 하지 마세요\n\n" +
                "번역할 목록: " + joined + "\n\n" +
                "번역 결과:";

        Map<String, Object> textPart = new HashMap<>();
        textPart.put("text", prompt);

        Map<String, Object> content = new HashMap<>();
        content.put("parts", List.of(textPart));

        Map<String, Object> requestBody = new HashMap<>();
        requestBody.put("contents", List.of(content));

        WebClient webClient = webClientBuilder.baseUrl(geminiApiUrl).build();
        Map response = webClient.post()
                .uri("/gemini-2.0-flash:generateContent?key=" + geminiApiKey)
                .header("Content-Type", "application/json")
                .bodyValue(requestBody)
                .retrieve()
                .bodyToMono(Map.class)
                .block();

        try {
            List<Map> candidates = (List<Map>) response.get("candidates");
            Map firstCandidate = candidates.get(0);
            Map responseContent = (Map) firstCandidate.get("content");
            List<Map> parts = (List<Map>) responseContent.get("parts");
            String rawText = (String) parts.get(0).get("text");

            List<String> result = new ArrayList<>();
            for (String item : rawText.split(",")) {
                String cleaned = item.trim()
                        .replaceAll("[\\n\\r·•\\-\\*\\d\\.\\(\\)]", "")
                        .trim();
                if (!cleaned.isEmpty() && cleaned.length() <= 20) {
                    result.add(cleaned);
                }
            }
            return result;
        } catch (Exception e) {
            // 번역 실패 시 영어 원본 반환
            return englishNames;
        }
    }
}
