package com.healthresponse.platform.directory;

import com.healthresponse.platform.directory.DirectoryService.DoctorView;
import com.healthresponse.platform.directory.DirectoryService.HospitalView;
import com.healthresponse.platform.directory.DirectoryService.Page;
import com.healthresponse.platform.directory.DirectoryService.Slot;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1")
public class DirectoryController {
    private final DirectoryService service;

    public DirectoryController(DirectoryService service) { this.service = service; }

    @GetMapping("/doctors")
    public Page<DoctorView> doctors(@RequestParam(required = false) String q,
                                    @RequestParam(required = false) String specialty,
                                    @RequestParam(required = false) UUID hospitalId,
                                    @RequestParam(defaultValue = "false") boolean verifiedOnly,
                                    @RequestParam(defaultValue = "0") int page,
                                    @RequestParam(defaultValue = "20") int size) {
        return service.doctors(q, specialty, hospitalId, verifiedOnly, page, size);
    }

    @GetMapping("/doctors/{id}")
    public DoctorView doctor(@PathVariable UUID id) { return service.doctor(id); }

    @GetMapping("/doctors/{id}/slots")
    public List<Slot> slots(@PathVariable UUID id, @RequestParam LocalDate date) { return service.slots(id, date); }

    @GetMapping("/hospitals")
    public Page<HospitalView> hospitals(@RequestParam(required = false) String q,
                                        @RequestParam(required = false) String city,
                                        @RequestParam(required = false) Double lat,
                                        @RequestParam(required = false) Double lon,
                                        @RequestParam(defaultValue = "0") int page,
                                        @RequestParam(defaultValue = "20") int size) {
        return service.hospitals(q, city, lat, lon, page, size);
    }

    @GetMapping("/hospitals/{id}")
    public HospitalView hospital(@PathVariable UUID id) { return service.hospital(id); }
}
