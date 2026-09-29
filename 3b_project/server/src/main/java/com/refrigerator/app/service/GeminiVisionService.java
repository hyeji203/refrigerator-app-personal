package com.refrigerator.app.service;

import com.refrigerator.app.dto.ScanResponseDto;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.reactive.function.client.WebClient;

import java.util.*;

@Service
public class GeminiVisionService {

    private static final Logger log = LoggerFactory.getLogger(GeminiVisionService.class);

    @Value("${gemini.api.key}")
    private String geminiApiKey;

    @Value("${gemini.api.url}")
    private String geminiApiUrl;

    private final WebClient.Builder webClientBuilder;

    public GeminiVisionService(WebClient.Builder webClientBuilder) {
        this.webClientBuilder = webClientBuilder;
    }

    /**
     * 냉장고 사진을 Gemini Vision API로 분석하여 식재료 목록만 반환합니다.
     * DB 저장은 하지 않습니다 - 사용자가 검토 후 확정하면 저장합니다.
     */
    public ScanResponseDto analyzeImage(MultipartFile imageFile) {
        try {
            String base64Image = Base64.getEncoder().encodeToString(imageFile.getBytes());
            String mimeType = imageFile.getContentType() != null
                    ? imageFile.getContentType() : "image/jpeg";

            Map<String, Object> requestBody = buildVisionRequest(base64Image, mimeType);

            WebClient webClient = webClientBuilder.build();
            Map response = webClient.post()
                    .uri(geminiApiUrl + "/gemini-3-flash-preview:generateContent?key=" + geminiApiKey)
                    .header("Content-Type", "application/json")
                    .bodyValue(requestBody)
                    .retrieve()
                    .bodyToMono(Map.class)
                    .block();

            List<String> ingredients = parseIngredientList(response);

            return ScanResponseDto.builder()
                    .recognizedIngredients(ingredients)
                    .build();

        } catch (org.springframework.web.reactive.function.client.WebClientResponseException e) {
            String body = e.getResponseBodyAsString();
            log.error("Gemini API 오류 - Status: {}, Body: {}", e.getStatusCode(), body);
            throw new RuntimeException(e.getStatusCode() + " - " + body);
        } catch (Exception e) {
            log.error("Gemini 이미지 분석 오류", e);
            throw new RuntimeException("이미지 분석 중 오류가 발생했습니다: " + e.getMessage());
        }
    }

    private Map<String, Object> buildVisionRequest(String base64Image, String mimeType) {
        // 이미지 파트
        Map<String, Object> inlineData = new HashMap<>();
        inlineData.put("mime_type", mimeType);
        inlineData.put("data", base64Image);

        Map<String, Object> imagePart = new HashMap<>();
        imagePart.put("inline_data", inlineData);

        // 텍스트 프롬프트 - 정확한 식재료만 추출하도록 명확하게 지시
        String prompt =
                "이 사진에서 냉장고 안에 있는 식재료와 음식 재료를 모두 찾아주세요.\n\n" +
                "규칙:\n" +
                "- 식재료와 음식 재료만 추출하세요 (용기, 병, 포장재, 조리기구는 제외)\n" +
                "- 한국어 명칭을 사용하세요\n" +
                "- 각 재료명을 쉼표(,)로만 구분해서 한 줄로 출력하세요\n" +
                "- 수량, 단위, 설명 없이 재료명만 출력하세요\n" +
                "- 사진에 식재료가 없으면 '없음'이라고 출력하세요\n\n" +
                "출력 예시: 달걀, 우유, 당근, 양파, 두부, 고추장\n\n" +
                "재료 목록:";

        Map<String, Object> textPart = new HashMap<>();
        textPart.put("text", prompt);

        Map<String, Object> content = new HashMap<>();
        content.put("parts", List.of(textPart, imagePart));

        Map<String, Object> requestBody = new HashMap<>();
        requestBody.put("contents", List.of(content));

        return requestBody;
    }

    @SuppressWarnings("unchecked")
    private List<String> parseIngredientList(Map response) {
        try {
            List<Map> candidates = (List<Map>) response.get("candidates");
            Map firstCandidate = candidates.get(0);
            Map content = (Map) firstCandidate.get("content");
            List<Map> parts = (List<Map>) content.get("parts");
            String rawText = (String) parts.get(0).get("text");

            // "없음" 응답 처리
            if (rawText.trim().equals("없음")) {
                return new ArrayList<>();
            }

            // 쉼표 구분 파싱 + 불필요한 문자 제거
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
            return new ArrayList<>();
        }
    }
}
