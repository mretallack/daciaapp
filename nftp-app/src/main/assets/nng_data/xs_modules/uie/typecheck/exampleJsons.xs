export const jsonStr = {
  "iterator": `
[
  {
    "name": "nng",
    "kind": "namespace",
    "items": [
      {
        "name": "core",
        "kind": "namespace",
        "items": [
          {
            "name": "Iterator",
            "kind": "interface",
            "typeParams": [
              {
                "name": "T"
              }
            ],
            "members": [
              {
                "name": "next",
                "type": {
                  "kind": "callable",
                  "arguments": [],
                  "returnValue": {
                    "type": {
                      "kind": "union",
                      "items": [
                        {
                          "param": 0,
                          "name": "T"
                        },
                        "any"
                      ]
                    }
                  }
                }
              }
            ]
          }
        ]
      },
      {
        "name": "test",
        "kind": "namespace",
        "items": [
          {
            "name": "Foo",
            "kind": "interface",
            "members": [
              {
                "name": "prop",
                "type": "string"
              },
              {
                "name": "getIterator",
                "type": {
                  "kind": "callable",
                  "arguments": [],
                  "returnValue": {
                    "type": {
                      "path": [
                        "nng",
                        "core",
                        "Iterator"
                      ],
                      "kind": "generic",
                      "params": [
                        "int32"
                      ]
                    }
                  }
                }
              }
            ]
          }
        ]
      }
    ]
  }
]
`,
    "http": `
[
  {
    "name": "nng",
    "kind": "namespace",
    "items": [
      {
        "name": "networking",
        "kind": "namespace",
        "items": [
          {
            "name": "http",
            "kind": "namespace",
            "items": [
              {
                "name": "Headers",
                "kind": "interface",
                "members": [
                  {
                    "name": "entries",
                    "type": {
                      "kind": "array",
                      "params": [
                        {
                          "kind": "tuple",
                          "items": [
                            "string",
                            "string"
                          ]
                        }
                      ]
                    }
                  },
                  {
                    "name": "set",
                    "type": {
                      "kind": "callable",
                      "arguments": [
                        {
                          "name": "name",
                          "type": "string"
                        },
                        {
                          "name": "value",
                          "type": "string"
                        }
                      ]
                    }
                  },
                  {
                    "name": "append",
                    "type": {
                      "kind": "callable",
                      "arguments": [
                        {
                          "name": "name",
                          "type": "string"
                        },
                        {
                          "name": "value",
                          "type": "string"
                        }
                      ]
                    }
                  },
                  {
                    "name": "remove",
                    "type": {
                      "kind": "callable",
                      "arguments": [
                        {
                          "name": "name",
                          "type": "string"
                        }
                      ]
                    }
                  },
                  {
                    "name": "has",
                    "type": {
                      "kind": "callable",
                      "arguments": [
                        {
                          "name": "name",
                          "type": "string"
                        }
                      ],
                      "returnValue": {
                        "type": "bool"
                      }
                    }
                  },
                  {
                    "name": "get",
                    "type": {
                      "kind": "callable",
                      "arguments": [
                        {
                          "name": "name",
                          "type": "string"
                        }
                      ],
                      "returnValue": {
                        "type": "string"
                      }
                    }
                  },
                  {
                    "name": "clone",
                    "type": {
                      "kind": "callable",
                      "arguments": [],
                      "returnValue": {
                        "type": {
                          "path": [
                            "nng",
                            "networking",
                            "http",
                            "Headers"
                          ]
                        }
                      }
                    }
                  }
                ]
              },
              {
                "name": "Request",
                "kind": "interface",
                "members": [
                  {
                    "name": "scheme",
                    "type": {
                      "path": [
                        "nng",
                        "networking",
                        "http",
                        "Scheme"
                      ]
                    }
                  },
                  {
                    "name": "userInfo",
                    "type": "string"
                  },
                  {
                    "name": "host",
                    "type": "string"
                  },
                  {
                    "name": "port",
                    "type": "uint32"
                  },
                  {
                    "name": "path",
                    "type": "string"
                  },
                  {
                    "name": "fragment",
                    "type": "string"
                  },
                  {
                    "name": "method",
                    "type": {
                      "path": [
                        "nng",
                        "networking",
                        "http",
                        "Method"
                      ]
                    }
                  },
                  {
                    "name": "headers",
                    "type": {
                      "path": [
                        "nng",
                        "networking",
                        "http",
                        "Headers"
                      ]
                    }
                  },
                  {
                    "name": "body",
                    "type": {
                      "kind": "union",
                      "items": [
                        "string",
                        "bytes"
                      ]
                    }
                  },
                  {
                    "name": "clone",
                    "type": {
                      "kind": "callable",
                      "arguments": [],
                      "returnValue": {
                        "type": {
                          "path": [
                            "nng",
                            "networking",
                            "http",
                            "Request"
                          ]
                        }
                      }
                    }
                  },
                  {
                    "name": "fetch",
                    "type": {
                      "kind": "callable",
                      "arguments": [],
                      "returnValue": {
                        "type": {
                          "path": [
                            "nng",
                            "networking",
                            "http",
                            "Response"
                          ]
                        }
                      }
                    }
                  },
                  {
                    "name": "cancel",
                    "type": {
                      "kind": "callable",
                      "arguments": []
                    }
                  }
                ]
              },
              {
                "name": "Response",
                "kind": "interface",
                "members": [
                  {
                    "name": "error",
                    "type": {
                      "path": [
                        "nng",
                        "networking",
                        "http",
                        "Error"
                      ]
                    }
                  },
                  {
                    "name": "status",
                    "type": "uint32"
                  },
                  {
                    "name": "statusText",
                    "type": "string"
                  },
                  {
                    "name": "url",
                    "type": "string"
                  },
                  {
                    "name": "headers",
                    "type": {
                      "path": [
                        "nng",
                        "networking",
                        "http",
                        "Headers"
                      ]
                    }
                  },
                  {
                    "name": "body",
                    "type": {
                      "kind": "union",
                      "items": [
                        "string",
                        "bytes"
                      ]
                    }
                  }
                ]
              },
              {
                "name": "Client",
                "kind": "interface",
                "members": [
                  {
                    "name": "createRequest",
                    "type": {
                      "kind": "callable",
                      "arguments": [],
                      "returnValue": {
                        "type": {
                          "path": [
                            "nng",
                            "networking",
                            "http",
                            "Request"
                          ]
                        }
                      }
                    }
                  },
                  {
                    "name": "createRequest",
                    "type": {
                      "kind": "callable",
                      "arguments": [
                        {
                          "name": "url",
                          "type": "string"
                        }
                      ],
                      "returnValue": {
                        "type": {
                          "path": [
                            "nng",
                            "networking",
                            "http",
                            "Request"
                          ]
                        }
                      }
                    }
                  },
                  {
                    "name": "createRequest",
                    "type": {
                      "kind": "callable",
                      "arguments": [
                        {
                          "name": "url",
                          "type": "string"
                        },
                        {
                          "name": "body",
                          "type": "string"
                        }
                      ],
                      "returnValue": {
                        "type": {
                          "path": [
                            "nng",
                            "networking",
                            "http",
                            "Request"
                          ]
                        }
                      }
                    }
                  },
                  {
                    "name": "cancelFetches",
                    "type": {
                      "kind": "callable",
                      "arguments": []
                    }
                  }
                ]
              },
              {
                "name": "Error",
                "kind": "enum",
                "items": [
                  "NOERR",
                  "NETWORK_CONNECT_NOT_FOUND",
                  "NETWORK_CONNECT_TIMEOUT",
                  "NETWORK_CONNECT_OTHER",
                  "NETWORK_OTHER",
                  "NETWORK_TIMEOUT",
                  "PROTOCOL",
                  "CANCELLED",
                  "OTHER"
                ]
              },
              {
                "name": "Scheme",
                "kind": "enum",
                "items": [
                  "HTTP",
                  "HTTPS",
                  "SERVICE"
                ]
              },
              {
                "name": "Method",
                "kind": "enum",
                "items": [
                  "GET",
                  "HEAD",
                  "POST"
                ]
              }
            ]
          },
          {
            "name": "rest",
            "kind": "namespace",
            "items": [
              {
                "name": "service",
                "kind": "interface",
                "members": [
                  {
                    "name": "createClient",
                    "type": {
                      "kind": "callable",
                      "arguments": [
                        {
                          "name": "host",
                          "type": "string"
                        }
                      ],
                      "returnValue": {
                        "type": {
                          "path": [
                            "nng",
                            "networking",
                            "rest",
                            "Client"
                          ]
                        }
                      }
                    }
                  }
                ]
              },
              {
                "name": "Client",
                "kind": "interface",
                "members": [
                  {
                    "name": "host",
                    "type": "string"
                  },
                  {
                    "name": "url",
                    "type": "string"
                  },
                  {
                    "name": "createGetRequest",
                    "type": {
                      "kind": "callable",
                      "arguments": [
                        {
                          "name": "path",
                          "type": "string"
                        }
                      ],
                      "returnValue": {
                        "type": {
                          "path": [
                            "nng",
                            "networking",
                            "rest",
                            "Request"
                          ]
                        }
                      }
                    }
                  },
                  {
                    "name": "createGetRequest",
                    "type": {
                      "kind": "callable",
                      "arguments": [
                        {
                          "name": "path",
                          "type": "string"
                        }
                      ],
                      "returnValue": {
                        "type": {
                          "path": [
                            "nng",
                            "networking",
                            "rest",
                            "Request"
                          ]
                        }
                      }
                    }
                  },
                  {
                    "name": "createHeadRequest",
                    "type": {
                      "kind": "callable",
                      "arguments": [
                        {
                          "name": "path",
                          "type": "string"
                        }
                      ],
                      "returnValue": {
                        "type": {
                          "path": [
                            "nng",
                            "networking",
                            "rest",
                            "Request"
                          ]
                        }
                      }
                    }
                  },
                  {
                    "name": "createHeadRequest",
                    "type": {
                      "kind": "callable",
                      "arguments": [
                        {
                          "name": "path",
                          "type": "string"
                        }
                      ],
                      "returnValue": {
                        "type": {
                          "path": [
                            "nng",
                            "networking",
                            "rest",
                            "Request"
                          ]
                        }
                      }
                    }
                  },
                  {
                    "name": "createPostRequest",
                    "type": {
                      "kind": "callable",
                      "arguments": [
                        {
                          "name": "path",
                          "type": "string"
                        },
                        {
                          "name": "body",
                          "type": "string"
                        }
                      ],
                      "returnValue": {
                        "type": {
                          "path": [
                            "nng",
                            "networking",
                            "rest",
                            "Request"
                          ]
                        }
                      }
                    }
                  },
                  {
                    "name": "createPostRequest",
                    "type": {
                      "kind": "callable",
                      "arguments": [
                        {
                          "name": "path",
                          "type": "string"
                        },
                        {
                          "name": "body",
                          "type": "string"
                        }
                      ],
                      "returnValue": {
                        "type": {
                          "path": [
                            "nng",
                            "networking",
                            "rest",
                            "Request"
                          ]
                        }
                      }
                    }
                  },
                  {
                    "name": "cancelFetches",
                    "type": {
                      "kind": "callable",
                      "arguments": []
                    }
                  }
                ]
              },
              {
                "name": "Request",
                "kind": "interface",
                "members": [
                  {
                    "name": "path",
                    "type": "string"
                  },
                  {
                    "name": "port",
                    "type": "string"
                  },
                  {
                    "name": "body",
                    "type": "string"
                  },
                  {
                    "name": "method",
                    "type": {
                      "path": [
                        "nng",
                        "networking",
                        "http",
                        "Method"
                      ]
                    }
                  },
                  {
                    "name": "setHeader",
                    "type": {
                      "kind": "callable",
                      "arguments": [
                        {
                          "name": "key",
                          "type": "string"
                        },
                        {
                          "name": "value",
                          "type": "string"
                        }
                      ],
                      "returnValue": {
                        "type": {
                          "path": [
                            "nng",
                            "networking",
                            "rest",
                            "Request"
                          ]
                        }
                      }
                    }
                  },
                  {
                    "name": "getHeader",
                    "type": {
                      "kind": "callable",
                      "arguments": [
                        {
                          "name": "key",
                          "type": "string"
                        }
                      ],
                      "returnValue": {
                        "type": "string"
                      }
                    }
                  },
                  {
                    "name": "removeHeader",
                    "type": {
                      "kind": "callable",
                      "arguments": [
                        {
                          "name": "key",
                          "type": "string"
                        }
                      ],
                      "returnValue": {
                        "type": {
                          "path": [
                            "nng",
                            "networking",
                            "rest",
                            "Request"
                          ]
                        }
                      }
                    }
                  },
                  {
                    "name": "changePort",
                    "type": {
                      "kind": "callable",
                      "arguments": [
                        {
                          "name": "newPort",
                          "type": "string"
                        }
                      ]
                    }
                  },
                  {
                    "name": "changePort",
                    "type": {
                      "kind": "callable",
                      "arguments": [
                        {
                          "name": "newPort",
                          "type": "uint32"
                        }
                      ]
                    }
                  },
                  {
                    "name": "clone",
                    "type": {
                      "kind": "callable",
                      "arguments": [],
                      "returnValue": {
                        "type": {
                          "path": [
                            "nng",
                            "networking",
                            "rest",
                            "Request"
                          ]
                        }
                      }
                    }
                  },
                  {
                    "name": "fetch",
                    "type": {
                      "kind": "callable",
                      "arguments": [],
                      "returnValue": {
                        "type": {
                          "path": [
                            "nng",
                            "networking",
                            "rest",
                            "Response"
                          ]
                        }
                      }
                    }
                  },
                  {
                    "name": "cancel",
                    "type": {
                      "kind": "callable",
                      "arguments": []
                    }
                  }
                ]
              },
              {
                "name": "Response",
                "kind": "interface",
                "members": [
                  {
                    "name": "error",
                    "type": {
                      "path": [
                        "nng",
                        "networking",
                        "http",
                        "Error"
                      ]
                    }
                  },
                  {
                    "name": "status",
                    "type": "uint32"
                  },
                  {
                    "name": "statusText",
                    "type": "string"
                  },
                  {
                    "name": "url",
                    "type": "string"
                  },
                  {
                    "name": "headers",
                    "type": {
                      "path": [
                        "nng",
                        "networking",
                        "http",
                        "Headers"
                      ]
                    }
                  },
                  {
                    "name": "body",
                    "type": "string"
                  }
                ]
              }
            ]
          }
        ]
      }
    ]
  }
]
`,
};
