local dojo = {}

dojo.createBurner = function(self, config, cb)
    self.toriiClient:CreateBurner(
        config.playerAddress,
        config.playerSigningKey,
        function(success, burnerAccount)
            if not success then
                cb(false, "Can't create burner")
                return
            end
            dojo.burnerAccount = burnerAccount
            cb(true)
        end
    )
end

dojo.createToriiClient = function(_, config)
    dojo.config = config
    dojo.toriiClient = Dojo:CreateToriiClient(config.torii_url, config.rpc_url, config.world)
    dojo.toriiClient.OnConnect = function(success)
        if not success then
            print("Connection failed")
            return
        end
        config.onConnect(dojo.toriiClient)
    end
    dojo.toriiClient:Connect()
end

dojo.getModel = function(_, entity, modelName)
    if not entity then
        return
    end
    for key, model in pairs(entity) do
        if key == modelName then
            return model
        end
    end
end

dojo.setOnEntityUpdateCallbacks = function(self, callbacks)
    local clauseJsonStr = '[{ "Keys": { "keys": [], "models": [], "pattern_matching": "VariableLen" } }]'
    self.toriiClient:OnEntityUpdate(clauseJsonStr, function(entityKey, entity)
        for modelName, callback in pairs(callbacks) do
            local model = self:getModel(entity, modelName)
            if model then
                callback(entityKey, model, entity)
            end
        end
    end)
end

dojo.syncEntities = function(self, callbacks)
    self.toriiClient:Entities('{ "limit": 1000, "offset": 0 }', function(entities)
        if not entities then
            return
        end
        for entityKey, entity in pairs(entities) do
            for modelName, callback in pairs(callbacks) do
                local model = self:getModel(entity, modelName)
                if model then
                    callback(entityKey, model, entity)
                end
            end
        end
    end)
end

return dojo
