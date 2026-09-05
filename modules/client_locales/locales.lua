dofile 'neededtranslations'

-- private variables
local defaultLocaleName = 'en'
local installedLocales
local currentLocale

function sendLocale(localeName)
    local protocolGame = g_game.getProtocolGame()
    if protocolGame then
        protocolGame:sendExtendedOpcode(ExtendedIds.Locale, 'en')
        return true
    end
    return false
end

function createWindow()
    -- Language selection is permanently disabled; English is enforced
    return
end

function selectFirstLocale(name)
    if localesWindow then
        localesWindow:destroy()
        localesWindow = nil
    end
    setLocale('en')
end

-- hooked functions
function onGameStart()
    sendLocale('en')
end

function onExtendedLocales(protocol, opcode, buffer)
    -- Language selection is permanently disabled; English is enforced
end

-- public functions
function init()
    installedLocales = {}

    installLocales('/locales')

    setLocale('en')
    g_settings.set('locale', 'en')

    ProtocolGame.registerExtendedOpcode(ExtendedIds.Locale, onExtendedLocales)
    connect(g_game, {
        onGameStart = onGameStart
    })
end

function terminate()
    installedLocales = nil
    currentLocale = nil

    ProtocolGame.unregisterExtendedOpcode(ExtendedIds.Locale)
    if g_app.hasUpdater() then
        disconnect(g_app, {
            onUpdateFinished = createWindow,
        })
    else
        disconnect(g_app, {
            onRun = createWindow,
        })
    end
    disconnect(g_game, {
        onGameStart = onGameStart
    })
end

function generateNewTranslationTable(localename)
    local locale = installedLocales[localename]
    for _i, k in pairs(neededTranslations) do
        local trans = locale.translation[k]
        k = k:gsub('\n', '\\n')
        k = k:gsub('\t', '\\t')
        k = k:gsub('\"', '\\\"')
        if trans then
            trans = trans:gsub('\n', '\\n')
            trans = trans:gsub('\t', '\\t')
            trans = trans:gsub('\"', '\\\"')
        end
        if not trans then
            print('    ["' .. k .. '"]' .. ' = false,')
        else
            print('    ["' .. k .. '"]' .. ' = "' .. trans .. '",')
        end
    end
end

function installLocale(locale)
    if not locale or not locale.name then
        error('Unable to install locale.')
    end

    if _G.allowedLocales and not _G.allowedLocales[locale.name] then
        return
    end

    if locale.name ~= defaultLocaleName then
        local updatesNamesMissing = {}
        for _, k in pairs(neededTranslations) do
            if locale.translation[k] == nil then
                updatesNamesMissing[#updatesNamesMissing + 1] = k
            end
        end

        if #updatesNamesMissing > 0 then
            pdebug('Locale \'' .. locale.name .. '\' is missing ' .. #updatesNamesMissing .. ' translations.')
            for _, name in pairs(updatesNamesMissing) do
                pdebug('["' .. name .. '"] = \"\",')
            end
        end
    end

    local installedLocale = installedLocales[locale.name]
    if installedLocale then
        for word, translation in pairs(locale.translation) do
            installedLocale.translation[word] = translation
        end
    else
        installedLocales[locale.name] = locale
    end
end

function installLocales(directory)
    dofiles(directory)
end

function setLocale(name)
    local locale = installedLocales['en']
    if not locale then
        pwarning('Locale en does not exist.')
        return false
    end
    currentLocale = locale
    g_settings.set('locale', 'en')
    return true
end

function getInstalledLocales()
    return installedLocales
end

function getCurrentLocale()
    return currentLocale
end

-- global function used to translate texts
function _G.tr(text, ...)
    if currentLocale then
        if tonumber(text) and currentLocale.formatNumbers then
            local number = tostring(text):split('.')
            local out = ''
            local reverseNumber = number[1]:reverse()
            for i = 1, #reverseNumber do
                out = out .. reverseNumber:sub(i, i)
                if i % 3 == 0 and i ~= #number then
                    out = out .. currentLocale.thousandsSeperator
                end
            end

            if number[2] then
                out = number[2] .. currentLocale.decimalSeperator .. out
            end
            return out:reverse()
        elseif tostring(text) then
            local translation = currentLocale.translation[text]
            if not translation then
                if translation == nil then
                    if currentLocale.name ~= defaultLocaleName then
                        pdebug('Unable to translate: \"' .. text .. '\"')
                    end
                end
                translation = text
            end
            return string.format(translation, ...)
        end
    end
    return text
end
