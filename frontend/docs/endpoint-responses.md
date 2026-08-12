# Google Weather API Endpoint Response Examples

## Get current conditions

```
curl -X GET "https://weather.googleapis.com/v1/currentConditions:lookup?key=YOUR_API_KEY&location.latitude=37.4220&location.longitude=-122.0841"
```

```json
{
  "currentTime": "2025-01-28T22:04:12.025273178Z",
  "timeZone": {
    "id": "America/Los_Angeles"
  },
  "isDaytime": true,
  "weatherCondition": {
    "iconBaseUri": "https://maps.gstatic.com/weather/v1/sunny",
    "description": {
      "text": "Sunny",
      "languageCode": "en"
    },
    "type": "CLEAR"
  },
  "temperature": {
    "degrees": 13.7,
    "unit": "CELSIUS"
  },
  "feelsLikeTemperature": {
    "degrees": 13.1,
    "unit": "CELSIUS"
  },
  "dewPoint": {
    "degrees": 1.1,
    "unit": "CELSIUS"
  },
  "heatIndex": {
    "degrees": 13.7,
    "unit": "CELSIUS"
  },
  "windChill": {
    "degrees": 13.1,
    "unit": "CELSIUS"
  },
  "relativeHumidity": 42,
  "uvIndex": 1,
  "precipitation": {
    "probability": {
      "percent": 0,
      "type": "RAIN"
    },
    "qpf": {
      "quantity": 0,
      "unit": "MILLIMETERS"
    }
  },
  "thunderstormProbability": 0,
  "airPressure": {
    "meanSeaLevelMillibars": 1019.16
  },
  "wind": {
    "direction": {
      "degrees": 335,
      "cardinal": "NORTH_NORTHWEST"
    },
    "speed": {
      "value": 8,
      "unit": "KILOMETERS_PER_HOUR"
    },
    "gust": {
      "value": 18,
      "unit": "KILOMETERS_PER_HOUR"
    }
  },
  "visibility": {
    "distance": 16,
    "unit": "KILOMETERS"
  },
  "cloudCover": 0,
  "currentConditionsHistory": {
    "temperatureChange": {
      "degrees": -0.6,
      "unit": "CELSIUS"
    },
    "maxTemperature": {
      "degrees": 14.3,
      "unit": "CELSIUS"
    },
    "minTemperature": {
      "degrees": 3.7,
      "unit": "CELSIUS"
    },
    "qpf": {
      "quantity": 0,
      "unit": "MILLIMETERS"
    }
  }
}
```

## Get hourly forecast

```
curl -X GET "https://weather.googleapis.com/v1/forecast/hours:lookup?key=YOUR_API_KEY&location.latitude=37.4220&location.longitude=-122.0841&hours=3"
```

```json
{
  "forecastHours": [
    {
      "interval": {
        "startTime": "2025-02-05T23:00:00Z",
        "endTime": "2025-02-06T00:00:00Z"
      },
      "displayDateTime": {
        "year": 2025,
        "month": 2,
        "day": 5,
        "hours": 15,
        "utcOffset": "-28800s"
      },
      "isDaytime": true,
      "weatherCondition": {
        "iconBaseUri": "https://maps.gstatic.com/weather/v1/sunny",
        "description": {
          "text": "Sunny",
          "languageCode": "en"
        },
        "type": "CLEAR"
      },
      "temperature": {
        "degrees": 12.7,
        "unit": "CELSIUS"
      },
      "feelsLikeTemperature": {
        "degrees": 12,
        "unit": "CELSIUS"
      },
      "dewPoint": {
        "degrees": 2.7,
        "unit": "CELSIUS"
      },
      "heatIndex": {
        "degrees": 12.7,
        "unit": "CELSIUS"
      },
      "windChill": {
        "degrees": 12,
        "unit": "CELSIUS"
      },
      "wetBulbTemperature": {
        "degrees": 7.7,
        "unit": "CELSIUS"
      },
      "relativeHumidity": 51,
      "uvIndex": 1,
      "precipitation": {
        "probability": {
          "percent": 0,
          "type": "RAIN"
        },
        "qpf": {
          "quantity": 0,
          "unit": "MILLIMETERS"
        }
      },
      "thunderstormProbability": 0,
      "airPressure": {
        "meanSeaLevelMillibars": 1019.13
      },
      "wind": {
        "direction": {
          "degrees": 335,
          "cardinal": "NORTH_NORTHWEST"
        },
        "speed": {
          "value": 10,
          "unit": "KILOMETERS_PER_HOUR"
        },
        "gust": {
          "value": 19,
          "unit": "KILOMETERS_PER_HOUR"
        }
      },
      "visibility": {
        "distance": 16,
        "unit": "KILOMETERS"
      },
      "cloudCover": 0,
      "iceThickness": {
        "thickness": 0,
        "unit": "MILLIMETERS"
      }
    },
    {
      "interval": {
        "startTime": "2025-02-06T00:00:00Z",
        "endTime": "2025-02-06T01:00:00Z"
      },
      "displayDateTime": {
        "year": 2025,
        "month": 2,
        "day": 5,
        "hours": 16,
        "utcOffset": "-28800s"
      },
      "isDaytime": true,
      "weatherCondition": {
        "iconBaseUri": "https://maps.gstatic.com/weather/v1/sunny",
        "description": {
          "text": "Sunny",
          "languageCode": "en"
        },
        "type": "CLEAR"
      },
      "temperature": {
        "degrees": 12.5,
        "unit": "CELSIUS"
      },
      /.../
    },
    {
      "interval": {
        "startTime": "2025-02-06T01:00:00Z",
        "endTime": "2025-02-06T02:00:00Z"
      },
      "displayDateTime": {
        "year": 2025,
        "month": 2,
        "day": 5,
        "hours": 17,
        "utcOffset": "-28800s"
      },
      "isDaytime": true,
      "weatherCondition": {
        "iconBaseUri": "https://maps.gstatic.com/weather/v1/sunny",
        "description": {
          "text": "Sunny",
          "languageCode": "en"
        },
        "type": "CLEAR"
      },
      "temperature": {
        "degrees": 11.4,
        "unit": "CELSIUS"
      },
      /.../
    }
  ],
  "timeZone": {
    "id": "America/Los_Angeles"
  }
}
```

## Reverse geocoding

```
curl -X GET "https://geocode.googleapis.com/v4/geocode/location?location.latitude=37.4220&location.longitude=-122.0841&key=YOUR_API_KEY"
```

```json
{
  "results": [
    {
      "place": "places/ChIJj38IfwK6j4ARNcyPDnEGa9g",
      "placeId": "ChIJj38IfwK6j4ARNcyPDnEGa9g",
      "location": {
        "latitude": 37.4223639,
        "longitude": -122.0840952
      },
      "granularity": "ROOFTOP",
      "viewport": {
        "low": {
          "latitude": 37.421016869708495,
          "longitude": -122.08529308029151
        },
        "high": {
          "latitude": 37.423714830291495,
          "longitude": -122.08259511970851
        }
      },
      "bounds": {
        "low": {
          "latitude": 37.4220699,
          "longitude": -122.084958
        },
        "high": {
          "latitude": 37.4226618,
          "longitude": -122.08293019999999
        }
      },
      "formattedAddress": "Google Building 40, 1600 Amphitheatre Pkwy, Mountain View, CA 94043, USA",
      "postalAddress": {
        "regionCode": "US",
        "languageCode": "en",
        "postalCode": "94043-1351",
        "administrativeArea": "CA",
        "locality": "Mountain View",
        "addressLines": [
          "Google Building 40",
          "1600 Amphitheatre Pkwy"
        ]
      },
      "addressComponents": [
        {
          "longText": "Google Building 40",
          "shortText": "Google Building 40",
          "types": [
            "premise"
          ],
          "languageCode": "en"
        },
        {
          "longText": "1600",
          "shortText": "1600",
          "types": [
            "street_number"
          ]
        },
        {
          "longText": "Amphitheatre Parkway",
          "shortText": "Amphitheatre Pkwy",
          "types": [
            "route"
          ],
          "languageCode": "en"
        },
        {
          "longText": "Mountain View",
          "shortText": "Mountain View",
          "types": [
            "locality",
            "political"
          ],
          "languageCode": "en"
        },
        {
          "longText": "Santa Clara County",
          "shortText": "Santa Clara County",
          "types": [
            "administrative_area_level_2",
            "political"
          ],
          "languageCode": "en"
        },
        {
          "longText": "California",
          "shortText": "CA",
          "types": [
            "administrative_area_level_1",
            "political"
          ],
          "languageCode": "en"
        },
        {
          "longText": "United States",
          "shortText": "US",
          "types": [
            "country",
            "political"
          ],
          "languageCode": "en"
        },
        {
          "longText": "94043",
          "shortText": "94043",
          "types": [
            "postal_code"
          ]
        },
        {
          "longText": "1351",
          "shortText": "1351",
          "types": [
            "postal_code_suffix"
          ]
        }
      ],
      "types": [
        "premise",
        "street_address"
      ]
    },
    {
      "place": "places/ChIJN8KDNnq7j4AR18Xh9LVB4c4",
      "placeId": "ChIJN8KDNnq7j4AR18Xh9LVB4c4",
      "location": {
        "latitude": 37.4215304,
        "longitude": -122.08408329999999
      },
      "granularity": "ROOFTOP",
      "viewport": {
        "low": {
          "latitude": 37.420181419708506,
          "longitude": -122.08543228029149
        },
        "high": {
          "latitude": 37.422879380291505,
          "longitude": -122.08273431970851
        }
      },
      "formattedAddress": "1600 Amphitheatre Pkwy Building 43, Mountain View, CA 94043, USA",
      "postalAddress": {
        "regionCode": "US",
        "languageCode": "en",
        "postalCode": "94043",
        "administrativeArea": "CA",
        "locality": "Mountain View",
        "addressLines": [
          "1600 Amphitheatre Pkwy Building 43"
        ]
      },
      "addressComponents": [
        {
          "longText": "Building 43",
          "shortText": "Building 43",
          "types": [
            "subpremise"
          ],
          "languageCode": "und"
        },
        {
          "longText": "1600",
          "shortText": "1600",
          "types": [
            "street_number"
          ]
        },
        {
          "longText": "Amphitheatre Parkway",
          "shortText": "Amphitheatre Pkwy",
          "types": [
            "route"
          ],
          "languageCode": "en"
        },
        {
          "longText": "Mountain View",
          "shortText": "Mountain View",
          "types": [
            "locality",
            "political"
          ],
          "languageCode": "en"
        },
        {
          "longText": "Santa Clara County",
          "shortText": "Santa Clara County",
          "types": [
            "administrative_area_level_2",
            "political"
          ],
          "languageCode": "en"
        },
        {
          "longText": "California",
          "shortText": "CA",
          "types": [
            "administrative_area_level_1",
            "political"
          ],
          "languageCode": "en"
        },
        {
          "longText": "United States",
          "shortText": "US",
          "types": [
            "country",
            "political"
          ],
          "languageCode": "en"
        },
        {
          "longText": "94043",
          "shortText": "94043",
          "types": [
            "postal_code"
          ]
        }
      ],
      "types": [
        "establishment",
        "point_of_interest"
      ],
      "plusCode": {
        "globalCode": "849VCWC8+J9",
        "compoundCode": "CWC8+J9 Mountain View, CA, USA"
      }
    },
    {
      "place": "places/GhIJvHSTGAS2QkAR_WX35GGFXsA",
      "placeId": "GhIJvHSTGAS2QkAR_WX35GGFXsA",
      "location": {
        "latitude": 37.422,
        "longitude": -122.08409999999999
      },
      "granularity": "GEOMETRIC_CENTER",
      "viewport": {
        "low": {
          "latitude": 37.4205885197085,
          "longitude": -122.0854114802915
        },
        "high": {
          "latitude": 37.4232864802915,
          "longitude": -122.08271351970852
        }
      },
      "bounds": {
        "low": {
          "latitude": 37.421875000000007,
          "longitude": -122.08412500000001
        },
        "high": {
          "latitude": 37.422,
          "longitude": -122.084
        }
      },
      "formattedAddress": "CWC8+Q9, Mountain View, CA, USA",
      "addressComponents": [
        {
          "longText": "CWC8+Q9",
          "shortText": "CWC8+Q9",
          "types": [
            "plus_code"
          ]
        },
        {
          "longText": "Mountain View",
          "shortText": "Mountain View",
          "types": [
            "locality",
            "political"
          ],
          "languageCode": "en"
        },
        {
          "longText": "Santa Clara County",
          "shortText": "Santa Clara County",
          "types": [
            "administrative_area_level_2",
            "political"
          ],
          "languageCode": "en"
        },
        {
          "longText": "California",
          "shortText": "CA",
          "types": [
            "administrative_area_level_1",
            "political"
          ],
          "languageCode": "en"
        },
        {
          "longText": "United States",
          "shortText": "US",
          "types": [
            "country",
            "political"
          ],
          "languageCode": "en"
        }
      ],
      "types": [
        "plus_code"
      ],
      "plusCode": {
        "globalCode": "849VCWC8+Q9",
        "compoundCode": "CWC8+Q9 Mountain View, CA, USA"
      }
    },
    {
      "place": "places/ChIJIfLyeQK6j4ARfP_oq3_3xVc",
      "placeId": "ChIJIfLyeQK6j4ARfP_oq3_3xVc",
      "location": {
        "latitude": 37.421931099999995,
        "longitude": -122.0841336
      },
      "granularity": "GEOMETRIC_CENTER",
      "viewport": {
        "low": {
          "latitude": 37.4206120697085,
          "longitude": -122.08547698029149
        },
        "high": {
          "latitude": 37.423310030291496,
          "longitude": -122.08277901970851
        }
      },
      "bounds": {
        "low": {
          "latitude": 37.4219261,
          "longitude": -122.0843352
        },
        "high": {
          "latitude": 37.421996,
          "longitude": -122.0839208
        }
      },
      "formattedAddress": "Unnamed Road, Mountain View, CA 94043, USA",
      "addressComponents": [
        {
          "longText": "Unnamed Road",
          "shortText": "Unnamed Road",
          "types": [
            "route"
          ],
          "languageCode": "en"
        },
        {
          "longText": "Mountain View",
          "shortText": "Mountain View",
          "types": [
            "locality",
            "political"
          ],
          "languageCode": "en"
        },
        {
          "longText": "Santa Clara County",
          "shortText": "Santa Clara County",
          "types": [
            "administrative_area_level_2",
            "political"
          ],
          "languageCode": "en"
        },
        {
          "longText": "California",
          "shortText": "CA",
          "types": [
            "administrative_area_level_1",
            "political"
          ],
          "languageCode": "en"
        },
        {
          "longText": "United States",
          "shortText": "US",
          "types": [
            "country",
            "political"
          ],
          "languageCode": "en"
        },
        {
          "longText": "94043",
          "shortText": "94043",
          "types": [
            "postal_code"
          ]
        }
      ],
      "types": [
        "route"
      ]
    },
    {
      "place": "places/ChIJoQmen1G3j4ARbhoe7nVBEoQ",
      "placeId": "ChIJoQmen1G3j4ARbhoe7nVBEoQ",
      "location": {
        "latitude": 37.4121862,
        "longitude": -122.05751339999999
      },
      "granularity": "APPROXIMATE",
      "viewport": {
        "low": {
          "latitude": 37.3857439,
          "longitude": -122.10842
        },
        "high": {
          "latitude": 37.452092100000009,
          "longitude": -122.03598989999999
        }
      },
      "bounds": {
        "low": {
          "latitude": 37.3857439,
          "longitude": -122.10842
        },
        "high": {
          "latitude": 37.452092100000009,
          "longitude": -122.03598989999999
        }
      },
      "formattedAddress": "Mountain View, CA 94043, USA",
      "addressComponents": [
        {
          "longText": "94043",
          "shortText": "94043",
          "types": [
            "postal_code"
          ]
        },
        {
          "longText": "Mountain View",
          "shortText": "Mountain View",
          "types": [
            "locality",
            "political"
          ],
          "languageCode": "en"
        },
        {
          "longText": "Santa Clara County",
          "shortText": "Santa Clara County",
          "types": [
            "administrative_area_level_2",
            "political"
          ],
          "languageCode": "en"
        },
        {
          "longText": "California",
          "shortText": "CA",
          "types": [
            "administrative_area_level_1",
            "political"
          ],
          "languageCode": "en"
        },
        {
          "longText": "United States",
          "shortText": "US",
          "types": [
            "country",
            "political"
          ],
          "languageCode": "en"
        }
      ],
      "postalCodeLocalities": [
        {
          "text": "Mountain View",
          "languageCode": "en"
        }
      ],
      "types": [
        "postal_code"
      ]
    },
    {
      "place": "places/ChIJiQHsW0m3j4ARm69rRkrUF3w",
      "placeId": "ChIJiQHsW0m3j4ARm69rRkrUF3w",
      "location": {
        "latitude": 37.390026399999996,
        "longitude": -122.08123040000001
      },
      "granularity": "APPROXIMATE",
      "viewport": {
        "low": {
          "latitude": 37.3540679,
          "longitude": -122.11762209999999
        },
        "high": {
          "latitude": 37.469887,
          "longitude": -122.04497909999998
        }
      },
      "bounds": {
        "low": {
          "latitude": 37.3540679,
          "longitude": -122.11762209999999
        },
        "high": {
          "latitude": 37.469887,
          "longitude": -122.04497909999998
        }
      },
      "formattedAddress": "Mountain View, CA, USA",
      "addressComponents": [
        {
          "longText": "Mountain View",
          "shortText": "Mountain View",
          "types": [
            "locality",
            "political"
          ],
          "languageCode": "en"
        },
        {
          "longText": "Santa Clara County",
          "shortText": "Santa Clara County",
          "types": [
            "administrative_area_level_2",
            "political"
          ],
          "languageCode": "en"
        },
        {
          "longText": "California",
          "shortText": "CA",
          "types": [
            "administrative_area_level_1",
            "political"
          ],
          "languageCode": "en"
        },
        {
          "longText": "United States",
          "shortText": "US",
          "types": [
            "country",
            "political"
          ],
          "languageCode": "en"
        }
      ],
      "types": [
        "locality",
        "political"
      ]
    },
    {
      "place": "places/ChIJd_Y0eVIvkIARuQyDN0F1LBA",
      "placeId": "ChIJd_Y0eVIvkIARuQyDN0F1LBA",
      "location": {
        "latitude": 37.2938907,
        "longitude": -121.7195459
      },
      "granularity": "APPROXIMATE",
      "viewport": {
        "low": {
          "latitude": 36.892975899999996,
          "longitude": -122.20265299999998
        },
        "high": {
          "latitude": 37.484637,
          "longitude": -121.20817799999999
        }
      },
      "bounds": {
        "low": {
          "latitude": 36.892975899999996,
          "longitude": -122.20265299999998
        },
        "high": {
          "latitude": 37.484637,
          "longitude": -121.20817799999999
        }
      },
      "formattedAddress": "Santa Clara County, CA, USA",
      "addressComponents": [
        {
          "longText": "Santa Clara County",
          "shortText": "Santa Clara County",
          "types": [
            "administrative_area_level_2",
            "political"
          ],
          "languageCode": "en"
        },
        {
          "longText": "California",
          "shortText": "CA",
          "types": [
            "administrative_area_level_1",
            "political"
          ],
          "languageCode": "en"
        },
        {
          "longText": "United States",
          "shortText": "US",
          "types": [
            "country",
            "political"
          ],
          "languageCode": "en"
        }
      ],
      "types": [
        "administrative_area_level_2",
        "political"
      ]
    },
    {
      "place": "places/ChIJPV4oX_65j4ARVW8IJ6IJUYs",
      "placeId": "ChIJPV4oX_65j4ARVW8IJ6IJUYs",
      "location": {
        "latitude": 36.778261,
        "longitude": -119.41793240000001
      },
      "granularity": "APPROXIMATE",
      "viewport": {
        "low": {
          "latitude": 32.529508100000008,
          "longitude": -124.482003
        },
        "high": {
          "latitude": 42.009502999999995,
          "longitude": -114.131211
        }
      },
      "bounds": {
        "low": {
          "latitude": 32.529508100000008,
          "longitude": -124.482003
        },
        "high": {
          "latitude": 42.009502999999995,
          "longitude": -114.131211
        }
      },
      "formattedAddress": "California, USA",
      "addressComponents": [
        {
          "longText": "California",
          "shortText": "CA",
          "types": [
            "administrative_area_level_1",
            "political"
          ],
          "languageCode": "en"
        },
        {
          "longText": "United States",
          "shortText": "US",
          "types": [
            "country",
            "political"
          ],
          "languageCode": "en"
        }
      ],
      "types": [
        "administrative_area_level_1",
        "political"
      ]
    },
    {
      "place": "places/ChIJCzYy5IS16lQRQrfeQ5K5Oxw",
      "placeId": "ChIJCzYy5IS16lQRQrfeQ5K5Oxw",
      "location": {
        "latitude": 38.794595199999996,
        "longitude": -106.5348379
      },
      "granularity": "APPROXIMATE",
      "viewport": {
        "low": {
          "latitude": 18.7763,
          "longitude": 166.99999990000003
        },
        "high": {
          "latitude": 74.071038,
          "longitude": -66.885417
        }
      },
      "bounds": {
        "low": {
          "latitude": 18.7763,
          "longitude": 166.99999990000003
        },
        "high": {
          "latitude": 74.071038,
          "longitude": -66.885417
        }
      },
      "formattedAddress": "United States",
      "addressComponents": [
        {
          "longText": "United States",
          "shortText": "US",
          "types": [
            "country",
            "political"
          ],
          "languageCode": "en"
        }
      ],
      "types": [
        "country",
        "political"
      ]
    }
  ],
  "plusCode": {
    "globalCode": "849VCWC8+Q9R",
    "compoundCode": "CWC8+Q9R Mountain View, CA, USA"
  }
}
```