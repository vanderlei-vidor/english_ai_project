# AI English Tutor

An AI-powered English learning platform designed to deliver immersive, adaptive, and personalized language learning experiences.

Built with Flutter, FastAPI, PostgreSQL, and LM Studio, the platform combines conversational AI, grammar correction, educational feedback, gamification systems, speech interaction, and persistent memory to create a next-generation language learning experience.

## Overview

AI English Tutor goes beyond traditional chatbots by acting as a personalized language coach capable of:

* Conducting natural conversations
* Correcting grammar mistakes
* Explaining concepts in Portuguese
* Adapting content to the learner's level
* Tracking long-term progress
* Maintaining learning context through memory systems
* Motivating users through gamification

The project was designed around the idea that language learning should feel engaging, interactive, and personalized.

## Key Features

### Conversational AI

* Natural language conversations
* Real-time response generation
* Context-aware interactions
* Local AI inference through LM Studio

### Intelligent Feedback

* Grammar correction
* Personalized explanations
* Practical examples
* Adaptive exercises

### Adaptive Learning

* Automatic learner profiling
* CEFR progression (A1 → C2)
* Topic detection
* Personalized recommendations

### Gamification System

* XP progression
* Achievement badges
* Daily streaks
* Weekly leagues
* Competitive ranking system

### Immersive User Experience

* Glassmorphism UI
* Real-time response streaming
* Voice interaction
* Speech synthesis (TTS)
* Animated AI presence
* Premium visual design

## Tech Stack

### Frontend

* Flutter
* Dart

### Backend

* FastAPI
* Python
* SQLAlchemy

### Database

* PostgreSQL

### Artificial Intelligence

* LM Studio
* Qwen 2.5
* Conversational AI
* Adaptive Learning Systems

## Project Structure

backend/
frontend/

README.md
ROADMAP.md
ARCHITECTURE.md
AI_SYSTEM.md
GAME_SYSTEM.md

## Documentation

Additional project documentation is available:

* Architecture Overview
* AI System Design
* Gamification System
* Product Roadmap

These documents provide deeper insights into system architecture, learning mechanics, AI workflows, and future development plans.

## Vision

To create an AI-powered language learning experience that combines educational effectiveness, conversational intelligence, gamification, and premium user experience into a single platform.

## Status

Active Development

Open to improvements, experimentation, and future expansion.

## Environment Setup

Create a `.env` file based on `.env.example`.

Example:

DATABASE_URL=postgresql://USER:PASSWORD@localhost:5432/DATABASE_NAME

LM_STUDIO_URL=http://localhost:1234/v1/chat/completions
