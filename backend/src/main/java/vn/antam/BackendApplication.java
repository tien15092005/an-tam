package vn.antam;

import java.util.TimeZone;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
public class BackendApplication {

	public static void main(String[] args) {
		// The backend works in UTC; each elder's local time zone is stored on their profile.
		// (Windows JVMs also report legacy zone ids such as "Asia/Saigon" that PostgreSQL 18 rejects.)
		TimeZone.setDefault(TimeZone.getTimeZone("UTC"));
		SpringApplication.run(BackendApplication.class, args);
	}

}
