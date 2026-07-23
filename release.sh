#!/bin/bash
# Запуск GUI-версии релиз-билдера
cd "$(dirname "$0")" && exec ./ReleaseBuilder.swift
