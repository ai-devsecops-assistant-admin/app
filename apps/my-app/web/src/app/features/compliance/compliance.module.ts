import { NgModule, Component } from '@angular/core';
import { CommonModule } from '@angular/common';
import { RouterModule, Routes } from '@angular/router';

@Component({
  selector: 'app-compliance',
  template: `
    <div class="compliance-container">
      <h2>Compliance Dashboard</h2>
      <p>Compliance monitoring features coming soon...</p>
    </div>
  `
})
export class ComplianceComponent {}

const routes: Routes = [
  {
    path: '',
    component: ComplianceComponent
  }
];

@NgModule({
  declarations: [
    ComplianceComponent
  ],
  imports: [
    CommonModule,
    RouterModule.forChild(routes)
  ]
})
export class ComplianceModule { }