import { Component, Input } from '@angular/core';

@Component({
  selector: 'app-metrics-widget',
  templateUrl: './metrics-widget.component.html',
  styleUrls: ['./metrics-widget.component.scss']
})
export class MetricsWidgetComponent {
  @Input() title: string = '';
  @Input() value: number = 0;
  @Input() unit: string = '';
  @Input() type: 'default' | 'success' | 'warning' | 'danger' = 'default';
  @Input() isPercentage: boolean = false;
}
