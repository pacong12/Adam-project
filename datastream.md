# Blynk Datastreams Configuration

## Virtual Pins Setup

| Virtual Pin | Name | Data Type | Min | Max | Default | Widget |
|-------------|------|-----------|-----|-----|---------|--------|
| V0 | Temperature | Double | -50 | 100 | 25 | Gauge/Value Display |
| V1 | Humidity | Double | 0 | 100 | 50 | Gauge/Value Display |
| V2 | Fan Status | String | - | - | OFF | Value Display |
| V3 | Manual Mode | Integer | 0 | 1 | 0 | Switch |
| V4 | Manual Fan | Integer | 0 | 1 | 0 | Button |
| V5 | Temp Threshold | Double | 20 | 50 | 30 | Slider |
| V6 | Humidity Threshold | Double | 30 | 90 | 60 | Slider |
| V7 | Start Hour | Integer | 0 | 23 | 7 | Numeric Input |
| V8 | End Hour | Integer | 0 | 23 | 14 | Numeric Input |
| V9 | Start Minute | Integer | 0 | 59 | 0 | Numeric Input |
| V10 | End Minute | Integer | 0 | 59 | 0 | Numeric Input |
| V11 | Current Time | String | - | - | 00:00 | Value Display |

## Widget Layout Suggestions

### Tab 1: Monitor
- **Temperature Gauge** (V0) - Shows current temperature
- **Humidity Gauge** (V1) - Shows current humidity  
- **Fan Status** (V2) - Shows ON/OFF status
- **Current Time** (V11) - Shows current time

### Tab 2: Control
- **Manual Mode Switch** (V3) - Toggle Auto/Manual mode
- **Manual Fan Button** (V4) - Manual fan control (only works in manual mode)

### Tab 3: Settings
- **Temperature Threshold Slider** (V5) - Set temperature trigger (20-50°C)
- **Humidity Threshold Slider** (V6) - Set humidity trigger (30-90%)

### Tab 4: Schedule
- **Start Hour** (V7) - Schedule start hour (0-23)
- **Start Minute** (V9) - Schedule start minute (0-59)
- **End Hour** (V8) - Schedule end hour (0-23)  
- **End Minute** (V10) - Schedule end minute (0-59)

## Setup Steps:

1. **Create Template** in Blynk Console
2. **Add Datastreams** according to table above
3. **Design Mobile Dashboard** with suggested widgets
4. **Get Auth Token** from device settings
5. **Update ESP32 code** with your credentials