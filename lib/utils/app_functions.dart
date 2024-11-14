import 'dart:core';
import 'package:flutter/material.dart';

// Function to validate the Egyptian National ID
String? validateEgyptianNationalID(String nationalID) {
  // Check if the National ID is exactly 14 digits long
  if (nationalID.length != 14) {
    return 'National ID must be 14 digits long';
  }

  // Validate that all characters are digits
  if (!RegExp(r'^\d+$').hasMatch(nationalID)) {
    return 'National ID must contain only digits';
  }

  return null; // Return null if the validation is successful
}

// Function to extract Date of Birth and Age from the Egyptian National ID
Map<String, String?> extractDOBAndAgeFromNationalID(String nationalID) {
  Map<String, String?> result = {
    'age': null,
    'dateOfBirth': null,
  };

  if (nationalID.length != 14 || !RegExp(r'^\d+$').hasMatch(nationalID)) {
    return result;  // Invalid ID format
  }

  // Extract day, month, and year from the National ID
  int day = int.parse(nationalID.substring(5, 7));   // 6th and 7th digits for day
  int month = int.parse(nationalID.substring(3, 5)); // 4th and 5th digits for month
  int yearOfBirth = int.parse(nationalID.substring(1, 3)); // 2nd and 3rd digits for year
  
  int currentYear = DateTime.now().year;
  int birthYear;

  // Determine full birth year (considering century transition)
  if (yearOfBirth > currentYear % 100) {
    birthYear = 1900 + yearOfBirth;
  } else {
    birthYear = 2000 + yearOfBirth;
  }

  // Construct the DateTime object for the date of birth
  DateTime dob = DateTime(birthYear, month, day);

  // Calculate the age based on the birth date and current date
  int age = currentYear - birthYear;
  if (DateTime.now().isBefore(DateTime(currentYear, month, day))) {
    age--;  // If the current date is before the birthday in the current year, subtract 1
  }

  // Convert the date of birth to a string (e.g., "DD/MM/YYYY")
  String dateOfBirth = "${dob.day.toString().padLeft(2, '0')}/${dob.month.toString().padLeft(2, '0')}/${dob.year}";

  // Populate the result map
  result['age'] = age.toString();
  result['dateOfBirth'] = dateOfBirth;

  return result;
}

// Email Validation
String? validateEmail(String? value) {
  if (value == null || value.isEmpty) {
    return 'Email is required';
  }
  if (!value.contains('@') || !value.endsWith('.com')) {
    return 'Please enter a valid email (e.g., example@example.com)';
  }
  return null;
}

// Age Validation (Minimum age 18)
String? validateAge(String? value) {
  if (value == null || value.isEmpty) {
    return 'Age is required';
  }
  final int age = int.tryParse(value) ?? 0;
  if (age < 18) {
    return 'Age must be at least 18';
  }
  return null;
}

// Password Validation (At least 10 characters, uppercase, lowercase, special characters)
String? validatePassword(String? value) {
  if (value == null || value.isEmpty) {
    return 'Password is required';
  }
  if (value.length < 10) {
    return 'Password must be at least 10 characters';
  }
  if (!RegExp(r'^(?=.*[A-Z])(?=.*[a-z])(?=.*[!@#$%^&*(),.?":{}|<>]).{10,}$').hasMatch(value)) {
    return 'Password must contain uppercase, lowercase letters, and special characters';
  }
  return null;
}

// Validate Egyptian phone number
String? validateEgyptianPhoneNumber(String? phoneNumber) {
  if (phoneNumber == null || phoneNumber.isEmpty) {
    return 'Phone number is required';
  }

  // Remove any spaces, dashes, or parentheses
  String cleanedNumber = phoneNumber.replaceAll(RegExp(r'[\s\-\(\)]'), '');

  // Check if the number starts with +20 or 20
  if (!cleanedNumber.startsWith('+20') && !cleanedNumber.startsWith('20')) {
    return 'Phone number must start with +20 or 20';
  }

  // Remove the country code for further validation
  if (cleanedNumber.startsWith('+20')) {
    cleanedNumber = cleanedNumber.substring(3);
  } else {
    cleanedNumber = cleanedNumber.substring(2);
  }

  // Check if the remaining number is exactly 10 digits long
  if (cleanedNumber.length != 10 || !RegExp(r'^\d+$').hasMatch(cleanedNumber)) {
    return 'Phone number must be exactly 10 digits';
  }

  // Check if the first digit of the 10-digit number is valid (e.g., 1, 10, 11, 12, etc.)
  String firstDigit = cleanedNumber[0];
  if (!['1', '2', '3', '4', '5', '6', '7', '8', '9'].contains(firstDigit)) {
    return 'Phone number starts with an invalid digit';
  }

  return null; // Valid phone number
}
