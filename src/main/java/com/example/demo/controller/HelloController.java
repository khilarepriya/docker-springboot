package com.example.demo.controller;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class HelloController {

    @GetMapping("/")
    public String hello() {
        return "Pipeline is working successfully";
    }

    @GetMapping("/health")
    public String health() {
        return "UP";
    }
}
