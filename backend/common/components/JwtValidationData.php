<?php

namespace common\components;

use sizeg\jwt\JwtValidationData as BaseJwtValidationData;

class JwtValidationData extends BaseJwtValidationData
{
    public function init()
    {
        $this->validationData->setIssuer(getenv('BACKEND_URL') ?: 'http://localhost:8080');
        $this->validationData->setAudience(getenv('BACKEND_URL') ?: 'http://localhost:8080');
        $this->validationData->setId('eco-client-cabinet');

        parent::init();
    }
}

