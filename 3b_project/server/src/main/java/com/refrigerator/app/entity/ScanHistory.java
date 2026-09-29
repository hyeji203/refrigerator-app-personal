package com.refrigerator.app.entity;

import jakarta.persistence.*;
import java.time.LocalDateTime;

@Entity
@Table(name = "SCAN_HISTORY")
public class ScanHistory {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "SCAN_ID")
    private Long scanId;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "USER_ID", nullable = false)
    private User user;

    @Column(name = "IMAGE_URL", length = 500)
    private String imageUrl;

    @Lob
    @Column(name = "RECOGNIZED_JSON")
    private String recognizedJson;

    @Column(name = "CREATED_AT")
    private LocalDateTime createdAt;

    public ScanHistory() {}

    public ScanHistory(User user, String recognizedJson) {
        this.user = user;
        this.recognizedJson = recognizedJson;
        this.createdAt = LocalDateTime.now();
    }

    public Long getScanId() { return scanId; }
    public User getUser() { return user; }
    public String getRecognizedJson() { return recognizedJson; }
    public LocalDateTime getCreatedAt() { return createdAt; }
}
