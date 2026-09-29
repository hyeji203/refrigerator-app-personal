package com.refrigerator.app.entity;

import jakarta.persistence.*;

@Entity
@Table(name = "USER_ALLERGIES")
public class UserAllergy {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "ALLERGY_ID")
    private Long allergyId;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "USER_ID", nullable = false)
    private User user;

    @Column(name = "ALLERGEN", nullable = false, length = 100)
    private String allergen;

    public UserAllergy() {}

    public UserAllergy(User user, String allergen) {
        this.user = user;
        this.allergen = allergen;
    }

    public Long getAllergyId() { return allergyId; }
    public User getUser() { return user; }
    public void setUser(User user) { this.user = user; }
    public String getAllergen() { return allergen; }
    public void setAllergen(String allergen) { this.allergen = allergen; }
}
