import { Component, OnInit } from '@angular/core';
import { ApiService } from '../../core/services/api.service';

export interface DashboardMetrics {
  namingComplianceRate: number;
  totalResources: number;
  violations: number;
  autoFixedIssues: number;
}

@Component({
  selector: 'app-dashboard',
  templateUrl: './dashboard.component.html',
  styleUrls: ['./dashboard.component.scss']
})
export class DashboardComponent implements OnInit {
  metrics: DashboardMetrics | null = null;
  loading = true;

  constructor(private apiService: ApiService) {}

  ngOnInit(): void {
    this.loadMetrics();
  }

  loadMetrics(): void {
    this.loading = true;
    this.apiService.get<DashboardMetrics>('/api/v1/metrics/dashboard')
      .subscribe({
        next: (data) => {
          this.metrics = data;
          this.loading = false;
        },
        error: (err) => {
          console.error('Failed to load metrics', err);
          this.loading = false;
        }
      });
  }
}
