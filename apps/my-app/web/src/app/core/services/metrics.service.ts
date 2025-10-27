import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { environment } from '../../../environments/environment';

@Injectable({
  providedIn: 'root'
})
export class MetricsService {
  constructor(private http: HttpClient) {}

  recordPageView(url: string): void {
    if (environment.production) {
      this.http.post(`${environment.apiUrl}/metrics/pageview`, {
        url,
        timestamp: new Date().toISOString(),
        userAgent: navigator.userAgent
      }).subscribe();
    }
  }

  recordEvent(category: string, action: string, label?: string, value?: number): void {
    if (environment.production) {
      this.http.post(`${environment.apiUrl}/metrics/event`, {
        category,
        action,
        label,
        value,
        timestamp: new Date().toISOString()
      }).subscribe();
    }
  }
}
