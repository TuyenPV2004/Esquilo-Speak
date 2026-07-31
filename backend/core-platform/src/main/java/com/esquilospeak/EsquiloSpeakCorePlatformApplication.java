package com.esquilospeak;

import org.springframework.boot.SpringApplication;
import org.springframework.modulith.Modulith;
import org.springframework.scheduling.annotation.EnableScheduling;

@Modulith
@EnableScheduling
public class EsquiloSpeakCorePlatformApplication {

	public static void main(String[] args) {
		SpringApplication.run(EsquiloSpeakCorePlatformApplication.class, args);
	}

}
