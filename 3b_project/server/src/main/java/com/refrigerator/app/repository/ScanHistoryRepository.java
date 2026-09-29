package com.refrigerator.app.repository;

import com.refrigerator.app.entity.ScanHistory;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ScanHistoryRepository extends JpaRepository<ScanHistory, Long> {
}