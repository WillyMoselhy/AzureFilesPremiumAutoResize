@description('The region where resources are stored')
param Location string = resourceGroup().location

@description('The name of the logic app.')
param LogicAppName string

@description('The time of day to trigger the logic app. (Default: 0 = midnight)')
param TriggerTime string = '0' // 0 = midnight, 1 = 1am, 2 = 2am, etc...

@description('The time zone of the trigger time. (Default: GMT Standard Time)')
param TriggerTimeZone string = 'GMT Standard Time'

@description('The resource Id of the storage accounts to resize.')
param StorageAccountIds array = []

@description('The target free space (buffer) in GB. (Default: 50GB)')
param TargetFreeSpaceGB int = 50

var varLogicAppDefinition = {
  '$schema': 'https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#'
  actions: {
    'Initialize_variable_-_File_Capacity': {
      inputs: {
        variables: [
          {
            name: 'File Capacity'
            type: 'float'
            value: 0
          }
        ]
      }
      runAfter: {
        'Initialize_variable_-_TargetFreeSpace': [
          'Succeeded'
        ]
      }
      type: 'InitializeVariable'
    }
    'Initialize_variable_-_Storage_Account_Id_Array': {
      inputs: {
        variables: [
          {
            name: 'StorageAccountId'
            type: 'array'
            value: StorageAccountIds
          }
        ]
      }
      runAfter: {
      }
      type: 'InitializeVariable'
    }
    'Initialize_variable_-_TargetFreeSpace': {
      description: '${TargetFreeSpaceGB} GB'
      inputs: {
        variables: [
          {
            name: 'TargetFreeSpace'
            type: 'float'
            value: TargetFreeSpaceGB * 1024 * 1024 * 1024
          }
        ]
      }
      runAfter: {
        'Initialize_variable_-_Storage_Account_Id_Array': [
          'Succeeded'
        ]
      }
      type: 'InitializeVariable'
    }
    Process_for_each_Storage_Account_Id: {
      actions: {
        Get_List_of_File_Shares_in_Storage_Account: {
          inputs: {
            authentication: {
              audience: 'https://management.azure.com/'
              type: 'ManagedServiceIdentity'
            }
            method: 'GET'
            queries: {
              'api-version': '2022-05-01'
            }
            uri: 'https://management.azure.com@{items(\'Process_for_each_Storage_Account_Id\')}/fileServices/default/shares'
          }
          runAfter: {
          }
          type: 'Http'
        }
        Parse_List_of_File_Shares: {
          inputs: {
            content: '@body(\'Get_List_of_File_Shares_in_Storage_Account\')'
            schema: {
              properties: {
                value: {
                  items: {
                    properties: {
                      etag: {
                        type: 'string'
                      }
                      id: {
                        type: 'string'
                      }
                      name: {
                        type: 'string'
                      }
                      properties: {
                        properties: {
                          accessTier: {
                            type: 'string'
                          }
                          enabledProtocols: {
                            type: 'string'
                          }
                          lastModifiedTime: {
                            type: 'string'
                          }
                          leaseState: {
                            type: 'string'
                          }
                          leaseStatus: {
                            type: 'string'
                          }
                          shareQuota: {
                            type: 'integer'
                          }
                        }
                        type: 'object'
                      }
                      type: {
                        type: 'string'
                      }
                    }
                    required: [
                      'id'
                      'name'
                      'type'
                      'etag'
                      'properties'
                    ]
                    type: 'object'
                  }
                  type: 'array'
                }
              }
              type: 'object'
            }
          }
          runAfter: {
            Get_List_of_File_Shares_in_Storage_Account: [
              'Succeeded'
            ]
          }
          type: 'ParseJson'
        }
        Process_for_each_File_Share: {
          actions: {
            Condition: {
              actions: {
                Set_Quota_to_Calculated_Target_Quota: {
                  inputs: {
                    authentication: {
                      audience: 'https://management.azure.com/'
                      type: 'ManagedServiceIdentity'
                    }
                    body: {
                      properties: {
                        shareQuota: '@int(first(split(string(div(add(variables(\'File Capacity\'),variables(\'TargetFreeSpace\')),1073741824)),\'.\')))'
                      }
                    }
                    method: 'PATCH'
                    queries: {
                      'api-version': '2022-05-01'
                    }
                    uri: 'https://management.azure.com@{items(\'Process_for_each_Storage_Account_Id\')}/fileServices/default/shares/@{items(\'Process_for_each_File_Share\')?[\'name\']}'
                  }
                  runAfter: {
                  }
                  type: 'Http'
                }
              }
              else: {
                actions: {
                  Set_quota_to_100_GB: {
                    inputs: {
                      authentication: {
                        audience: 'https://management.azure.com/'
                        type: 'ManagedServiceIdentity'
                      }
                      body: {
                        properties: {
                          shareQuota: 100
                        }
                      }
                      method: 'PATCH'
                      queries: {
                        'api-version': '2022-05-01'
                      }
                      uri: 'https://management.azure.com@{items(\'Process_for_each_Storage_Account_Id\')}/fileServices/default/shares/@{items(\'Process_for_each_File_Share\')?[\'name\']}'
                    }
                    runAfter: {
                    }
                    type: 'Http'
                  }
                }
              }
              expression: {
                and: [
                  {
                    greater: [
                      '@div(add(variables(\'File Capacity\'),variables(\'TargetFreeSpace\')),1073741824)'
                      100
                    ]
                  }
                ]
              }
              runAfter: {
                Extract_metric_value_from_parsed_JSON: [
                  'Succeeded'
                ]
              }
              type: 'If'
            }
            Extract_metric_value_from_parsed_JSON: {
              actions: {
                For_each_2: {
                  actions: {
                    For_each_3: {
                      actions: {
                        Set_variable: {
                          inputs: {
                            name: 'File Capacity'
                            value: '@items(\'For_each_3\')?[\'average\']'
                          }
                          runAfter: {
                          }
                          type: 'SetVariable'
                        }
                      }
                      foreach: '@items(\'For_each_2\')[\'data\']'
                      runAfter: {
                      }
                      type: 'Foreach'
                    }
                  }
                  foreach: '@items(\'Extract_metric_value_from_parsed_JSON\')[\'timeseries\']'
                  runAfter: {
                  }
                  type: 'Foreach'
                }
              }
              foreach: '@body(\'Parse_File_Capacity_metric_value\')?[\'value\']'
              runAfter: {
                Parse_File_Capacity_metric_value: [
                  'Succeeded'
                ]
              }
              type: 'Foreach'
            }
            Get_metric_File_Capacity_value_for_one_File_Share: {
              inputs: {
                authentication: {
                  audience: 'https://management.azure.com/'
                  type: 'ManagedServiceIdentity'
                }
                method: 'GET'
                queries: {
                  '$filter': 'FileShare eq \'@{items(\'Process_for_each_File_Share\')?[\'name\']}\''
                  aggregation: 'average'
                  'api-version': '2019-07-01'
                  interval: 'FULL'
                  metricNamespace: 'microsoft.storage/storageaccounts/fileservices'
                  metricnames: 'FileCapacity'
                }
                uri: 'https://management.azure.com@{items(\'Process_for_each_Storage_Account_Id\')}/fileServices/default/providers/Microsoft.Insights/metrics'
              }
              runAfter: {
              }
              type: 'Http'
            }
            Parse_File_Capacity_metric_value: {
              inputs: {
                content: '@body(\'Get_metric_File_Capacity_value_for_one_File_Share\')'
                schema: {
                  properties: {
                    cost: {
                      type: 'integer'
                    }
                    interval: {
                      type: 'string'
                    }
                    namespace: {
                      type: 'string'
                    }
                    resourceregion: {
                      type: 'string'
                    }
                    timespan: {
                      type: 'string'
                    }
                    value: {
                      items: {
                        properties: {
                          displayDescription: {
                            type: 'string'
                          }
                          errorCode: {
                            type: 'string'
                          }
                          id: {
                            type: 'string'
                          }
                          name: {
                            properties: {
                              localizedValue: {
                                type: 'string'
                              }
                              value: {
                                type: 'string'
                              }
                            }
                            type: 'object'
                          }
                          timeseries: {
                            items: {
                              properties: {
                                data: {
                                  items: {
                                    properties: {
                                      average: {
                                        type: 'integer'
                                      }
                                      timeStamp: {
                                        type: 'string'
                                      }
                                    }
                                    required: [
                                      'timeStamp'
                                      'average'
                                    ]
                                    type: 'object'
                                  }
                                  type: 'array'
                                }
                                metadatavalues: {
                                  items: {
                                    properties: {
                                      name: {
                                        properties: {
                                          localizedValue: {
                                            type: 'string'
                                          }
                                          value: {
                                            type: 'string'
                                          }
                                        }
                                        type: 'object'
                                      }
                                      value: {
                                        type: 'string'
                                      }
                                    }
                                    required: [
                                      'name'
                                      'value'
                                    ]
                                    type: 'object'
                                  }
                                  type: 'array'
                                }
                              }
                              required: [
                                'metadatavalues'
                                'data'
                              ]
                              type: 'object'
                            }
                            type: 'array'
                          }
                          type: {
                            type: 'string'
                          }
                          unit: {
                            type: 'string'
                          }
                        }
                        required: [
                          'id'
                          'type'
                          'name'
                          'displayDescription'
                          'unit'
                          'timeseries'
                          'errorCode'
                        ]
                        type: 'object'
                      }
                      type: 'array'
                    }
                  }
                  type: 'object'
                }
              }
              runAfter: {
                Get_metric_File_Capacity_value_for_one_File_Share: [
                  'Succeeded'
                ]
              }
              type: 'ParseJson'
            }
          }
          foreach: '@body(\'Parse_List_of_File_Shares\')?[\'value\']'
          runAfter: {
            Parse_List_of_File_Shares: [
              'Succeeded'
            ]
          }
          type: 'Foreach'
        }
      }
      foreach: '@variables(\'StorageAccountId\')'
      runAfter: {
        'Initialize_variable_-_File_Capacity': [
          'Succeeded'
        ]
      }
      type: 'Foreach'
    }
  }
  contentVersion: '1.0.0.0'
  outputs: {
  }
  parameters: {
  }
  triggers: {
    'Recurrence_-_Daily': {
      evaluatedRecurrence: {
        frequency: 'Day'
        interval: 1
        schedule: {
          hours: [
            TriggerTime
          ]
        }
        timeZone: TriggerTimeZone
      }
      recurrence: {
        frequency: 'Day'
        interval: 1
        schedule: {
          hours: [
            '0'
          ]
        }
        timeZone: TriggerTimeZone
      }
      type: 'Recurrence'
    }
  }
}
resource deployLogicApp 'Microsoft.Logic/workflows@2019-05-01' = {
  location: Location
  name: LogicAppName
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    state: 'Enabled'
    definition: any(varLogicAppDefinition)
    parameters: {}
  }
}

// *** Outputs *** //
output LogicAppSystemAssignedIdentityId string = deployLogicApp.identity.principalId
