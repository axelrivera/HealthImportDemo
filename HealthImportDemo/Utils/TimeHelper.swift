//
//  TimeHelper.swift
//  HealthImportDemo
//
//  Created by Axel Rivera on 11/10/24.
//

import Foundation

func secondsToHoursMinutesSeconds(seconds: Int) -> (Int, Int, Int) {
    (seconds / 3600, ((seconds % 3600) / 60), (seconds % 3600) % 60)
}

func timerDurationString(forDuration measurement: Measurement<UnitDuration>) -> String {
    let conversion = measurement.converted(to: .seconds)
    return timerDurationString(durationInseconds: conversion.value)
}

func timerDurationString(durationInseconds seconds: Double) -> String {
    let (h, m, s) = secondsToHoursMinutesSeconds(seconds: Int(seconds))
    
    if h > 0 {
        return String(format: "%d:%02d:%02d", h, m, s)
    } else {
        return String(format: "%02d:%02d", m, s)
    }
}
