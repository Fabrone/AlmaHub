import 'dart:io';
//import 'dart:typed_data';
import 'package:almahub/models/employee_onboarding_models.dart';
import 'package:excel/excel.dart';
import 'package:intl/intl.dart';

class ExcelGenerationService {
  /// Generate comprehensive Excel file with all employee onboarding data
  /// Returns both the file bytes and the filename
  static Future<Map<String, dynamic>> generateEmployeeOnboardingExcel(
    List<EmployeeOnboarding> employees,
  ) async {
    final excel = Excel.createExcel();
    final sheet = excel['Employee Onboarding Data'];

    // Set column widths for better readability
    sheet.setColumnWidth(0, 5.0);  // ID column
    sheet.setColumnWidth(1, 25.0); // Full Name
    sheet.setColumnWidth(2, 20.0); // National ID
    sheet.setColumnWidth(3, 15.0); // Date of Birth
    sheet.setColumnWidth(4, 12.0); // Gender
    sheet.setColumnWidth(5, 18.0); // Phone
    sheet.setColumnWidth(6, 25.0); // Email
    sheet.setColumnWidth(7, 30.0); // Address
    sheet.setColumnWidth(8, 20.0); // Next of Kin
    sheet.setColumnWidth(9, 20.0); // Job Title
    sheet.setColumnWidth(10, 18.0); // Department
    sheet.setColumnWidth(11, 15.0); // Employment Type
    sheet.setColumnWidth(12, 15.0); // Start Date
    sheet.setColumnWidth(13, 20.0); // Supervisor
    sheet.setColumnWidth(14, 18.0); // KRA PIN
    sheet.setColumnWidth(15, 18.0); // NSSF Number
    sheet.setColumnWidth(16, 18.0); // NHIF Number
    sheet.setColumnWidth(17, 18.0); // Basic Salary
    sheet.setColumnWidth(18, 20.0); // Allowances
    sheet.setColumnWidth(19, 20.0); // Deductions
    sheet.setColumnWidth(20, 20.0); // Bank Name
    sheet.setColumnWidth(21, 20.0); // Account Number
    sheet.setColumnWidth(22, 18.0); // M-Pesa
    sheet.setColumnWidth(23, 25.0); // Work Email
    sheet.setColumnWidth(24, 15.0); // Status
    sheet.setColumnWidth(25, 18.0); // Submitted Date

    // Header Row with styling
    final headerStyle = CellStyle(
      backgroundColorHex: ExcelColor.fromHexString('#1A237E'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      bold: true,
      fontSize: 11,
    );

    final headers = [
      'No.',
      'Full Name',
      'National ID/Passport',
      'Date of Birth',
      'Gender',
      'Phone Number',
      'Email Address',
      'Physical Address',
      'Next of Kin (Name, Relationship, Contact)',
      'Job Title',
      'Department',
      'Employment Type',
      'Start Date',
      'Supervisor/Manager',
      'KRA PIN',
      'NSSF Number',
      'NHIF Number',
      'Basic Salary (KES)',
      'Allowances (KES)',
      'Deductions (KES)',
      'Bank Name',
      'Account Number',
      'M-Pesa Number',
      'Work Email',
      'Status',
      'Submitted Date',
      'Postal Address',
      'Working Hours',
      'Work Location',
      'Professional Registrations',
      'Academic Certificates',
      'Professional Certificates',
      'Contract Signed',
      'NDA Signed',
      'Code of Conduct Acknowledged',
      'Data Protection Consent',
      'NHIF Dependants',
      'Beneficiaries',
      'Issued Equipment',
      'HRIS Profile Created',
      'System Access Granted',
      'Housing Allowance',
      'Transport Allowance',
      'Other Allowances',
      'Loans Deduction',
      'SACCO Deduction',
      'Advance Deduction',
      'Bank Branch',
      'M-Pesa Name',
    ];

    // Add headers
    for (int i = 0; i < headers.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = headerStyle;
    }

    // Data Rows
    final dataStyle = CellStyle(
      fontSize: 10,
    );

    final dateFormat = DateFormat('dd/MM/yyyy');
    final currencyFormat = NumberFormat('#,##0.00');

    for (int index = 0; index < employees.length; index++) {
      final employee = employees[index];
      final rowIndex = index + 1;

      // Helper function to format allowances/deductions
      String formatMoneyMap(Map<String, double> map) {
        if (map.isEmpty) return '-';
        return map.entries
            .map((e) => '${e.key}: KES ${currencyFormat.format(e.value)}')
            .join('; ');
      }

      // Helper function to get specific allowance
      double getAllowance(Map<String, double> allowances, String key) {
        return allowances[key] ?? 0.0;
      }

      // Helper function to get specific deduction
      double getDeduction(Map<String, double> deductions, String key) {
        return deductions[key] ?? 0.0;
      }

      final rowData = [
        rowIndex, // No.
        employee.personalInfo.fullName,
        employee.personalInfo.nationalIdOrPassport,
        employee.personalInfo.dateOfBirth != null
            ? dateFormat.format(employee.personalInfo.dateOfBirth!)
            : '',
        employee.personalInfo.gender,
        employee.personalInfo.phoneNumber,
        employee.personalInfo.email,
        employee.personalInfo.physicalAddress,
        '${employee.personalInfo.nextOfKin.name} (${employee.personalInfo.nextOfKin.relationship}) - ${employee.personalInfo.nextOfKin.contact}',
        employee.employmentDetails.jobTitle,
        employee.employmentDetails.department,
        employee.employmentDetails.employmentType,
        employee.employmentDetails.startDate != null
            ? dateFormat.format(employee.employmentDetails.startDate!)
            : '',
        employee.employmentDetails.supervisorName,
        employee.statutoryDocs.kraPinNumber,
        employee.statutoryDocs.nssfNumber,
        employee.statutoryDocs.nhifNumber,
        currencyFormat.format(employee.payrollDetails.basicSalary),
        formatMoneyMap(employee.payrollDetails.allowances),
        formatMoneyMap(employee.payrollDetails.deductions),
        employee.payrollDetails.bankDetails?.bankName ?? '',
        employee.payrollDetails.bankDetails?.accountNumber ?? '',
        employee.payrollDetails.mpesaDetails?.phoneNumber ?? '',
        employee.workTools.workEmail ?? '',
        employee.status.toUpperCase(),
        employee.submittedAt != null
            ? dateFormat.format(employee.submittedAt!)
            : '',
        employee.personalInfo.postalAddress,
        employee.employmentDetails.workingHours,
        employee.employmentDetails.workLocation,
        employee.academicDocs.professionalRegistrations.entries
            .map((e) => '${e.key}: ${e.value}')
            .join('; '),
        employee.academicDocs.academicCertificates.isNotEmpty
            ? '${employee.academicDocs.academicCertificates.length} certificates uploaded'
            : 'None',
        employee.academicDocs.professionalCertificates.isNotEmpty
            ? '${employee.academicDocs.professionalCertificates.length} certificates uploaded'
            : 'None',
        employee.contractsForms.employmentContractUrl != null ? 'Yes' : 'No',
        employee.contractsForms.ndaUrl != null ? 'Yes' : 'No',
        employee.contractsForms.codeOfConductAcknowledged ? 'Yes' : 'No',
        employee.contractsForms.dataProtectionConsentGiven ? 'Yes' : 'No',
        employee.benefitsInsurance.nhifDependants.isNotEmpty
            ? employee.benefitsInsurance.nhifDependants
                .map((d) => '${d.name} (${d.relationship})')
                .join('; ')
            : 'None',
        employee.benefitsInsurance.beneficiaries.isNotEmpty
            ? employee.benefitsInsurance.beneficiaries
                .map((b) => '${b.name} (${b.percentage}%)')
                .join('; ')
            : 'None',
        employee.workTools.issuedEquipment.isNotEmpty
            ? employee.workTools.issuedEquipment
                .map((e) => '${e.itemName} - ${e.serialNumber}')
                .join('; ')
            : 'None',
        employee.workTools.hrisProfileCreated ? 'Yes' : 'No',
        employee.workTools.systemAccessGranted ? 'Yes' : 'No',
        currencyFormat.format(getAllowance(employee.payrollDetails.allowances, 'housing')),
        currencyFormat.format(getAllowance(employee.payrollDetails.allowances, 'transport')),
        currencyFormat.format(getAllowance(employee.payrollDetails.allowances, 'other')),
        currencyFormat.format(getDeduction(employee.payrollDetails.deductions, 'loans')),
        currencyFormat.format(getDeduction(employee.payrollDetails.deductions, 'sacco')),
        currencyFormat.format(getDeduction(employee.payrollDetails.deductions, 'advance')),
        employee.payrollDetails.bankDetails?.branch ?? '',
        employee.payrollDetails.mpesaDetails?.name ?? '',
      ];

      for (int colIndex = 0; colIndex < rowData.length; colIndex++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: colIndex, rowIndex: rowIndex),
        );
        
        // Properly set cell value based on type
        final value = rowData[colIndex];
        if (value is int) {
          cell.value = IntCellValue(value);
        } else if (value is double) {
          cell.value = DoubleCellValue(value);
        } else {
          cell.value = TextCellValue(value.toString());
        }
        
        cell.cellStyle = dataStyle;
      }
    }

    // Freeze header row
    sheet.setRowHeight(0, 25);

    // Auto-filter on header row
    // Note: Excel package may not support this directly, but we set it up for manual use

    // Generate file
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final fileName = 'AlmaHub_Employee_Onboarding_$timestamp.xlsx';
    
    // Encode to bytes
    final bytes = excel.encode();
    
    return {
      'fileName': fileName,
      'fileBytes': bytes,
    };
  }

  /// Generate a summary statistics sheet
  static void addSummarySheet(Excel excel, List<EmployeeOnboarding> employees) {
    final summarySheet = excel['Summary'];

    // Header
    final titleCell = summarySheet.cell(CellIndex.indexByString('A1'));
    titleCell.value = TextCellValue('AlmaHub - Employee Onboarding Summary');
    titleCell.cellStyle = CellStyle(
      bold: true,
      fontSize: 16,
      fontColorHex: ExcelColor.fromHexString('#1A237E'),
    );

    // Statistics
    final totalEmployees = employees.length;
    final submitted = employees.where((e) => e.status == 'submitted').length;
    final approved = employees.where((e) => e.status == 'approved').length;
    final drafts = employees.where((e) => e.status == 'draft').length;

    final stats = [
      ['', ''],
      ['Total Employees:', totalEmployees],
      ['Submitted:', submitted],
      ['Approved:', approved],
      ['Drafts:', drafts],
      ['', ''],
      ['Report Generated:', DateFormat('dd MMMM yyyy HH:mm').format(DateTime.now())],
    ];

    for (int i = 0; i < stats.length; i++) {
      final labelCell = summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: i + 2));
      final labelValue = stats[i][0];
      labelCell.value = TextCellValue(labelValue.toString());
      labelCell.cellStyle = CellStyle(bold: true);

      final valueCell = summarySheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: i + 2));
      final cellValue = stats[i][1];
      if (cellValue is int) {
        valueCell.value = IntCellValue(cellValue);
      } else {
        valueCell.value = TextCellValue(cellValue.toString());
      }
    }

    summarySheet.setColumnWidth(0, 25.0);
    summarySheet.setColumnWidth(1, 20.0);
  }

  /// Save Excel file bytes (for mobile/desktop)
  static Future<File> saveExcelFile(List<int> fileBytes, String fileName) async {
    // For web, you would use different approach
    // For desktop/mobile:
    final directory = Directory.current.path;
    final file = File('$directory/$fileName');
    await file.writeAsBytes(fileBytes);
    return file;
  }
}